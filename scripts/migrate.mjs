import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import pg from 'pg';

// Operator-only entrypoint. Never import this module from application code.
// A single transaction holds the advisory lock through schema + ledger commit.
const migrationsDirectory = new URL('../db/migrations/', import.meta.url);
class MigrationError extends Error {}

async function loadMigrations() {
  const entries = await readdir(migrationsDirectory, { withFileTypes: true });
  const names = entries.filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
    .map((entry) => entry.name).sort();
  if (!names.length || names.some((name) => !/^\d{3}_[a-z0-9_]+\.sql$/.test(name))) {
    throw new MigrationError('Migration files must use NNN_lowercase_name.sql names.');
  }
  if (new Set(names.map((name) => name.slice(0, 3))).size !== names.length) {
    throw new MigrationError('Migration numeric prefixes must be unique.');
  }
  return Promise.all(names.map(async (version) => {
    const bytes = await readFile(new URL(version, migrationsDirectory));
    return {
      version,
      checksum: createHash('sha256').update(bytes).digest('hex'),
      sql: bytes.toString('utf8'),
    };
  }));
}

async function migrate() {
  const connectionString = process.env.DATABASE_MIGRATION_URL;
  if (!connectionString) throw new MigrationError('DATABASE_MIGRATION_URL is required.');
  const migrations = await loadMigrations();
  const client = new pg.Client({
    connectionString,
    connectionTimeoutMillis: 10_000,
    application_name: 'boarded-migrate',
  });
  let inTransaction = false;
  let applying = null;
  try {
    await client.connect();
    await client.query('BEGIN');
    inTransaction = true;
    await client.query("SET LOCAL lock_timeout = '30s'");
    await client.query("SET LOCAL statement_timeout = '5min'");
    await client.query("SET LOCAL search_path = pg_catalog, public");
    await client.query('SELECT pg_catalog.pg_advisory_xact_lock($1, $2)', [20260914, 1]);
    const identity = await client.query(`
      SELECT current_user AS role, current_database() AS database,
        app.rolsuper, app.rolcreatedb, app.rolcreaterole, app.rolbypassrls,
        pg_catalog.pg_has_role(app.oid, migrator.oid, 'MEMBER') AS inherits_migrator,
        db.datdba = app.oid AS app_owns_database
      FROM pg_catalog.pg_roles app
      CROSS JOIN pg_catalog.pg_roles migrator
      JOIN pg_catalog.pg_database db ON db.datname = current_database()
      WHERE app.rolname = 'boarded_app' AND migrator.rolname = 'boarded_migrator'
    `);
    const roles = identity.rows[0];
    if (!roles || roles.role !== 'boarded_migrator' || roles.database !== 'boarded'
      || roles.rolsuper || roles.rolcreatedb || roles.rolcreaterole || roles.rolbypassrls
      || roles.inherits_migrator || roles.app_owns_database) {
      throw new MigrationError('Use boarded_migrator on boarded with a separate, unprivileged boarded_app role.');
    }
    await client.query(`
      CREATE TABLE IF NOT EXISTS public.schema_migrations (
        version TEXT PRIMARY KEY,
        checksum TEXT NOT NULL CHECK (checksum ~ '^[0-9a-f]{64}$'),
        applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);
    await client.query('REVOKE ALL ON public.schema_migrations FROM PUBLIC, boarded_app');
    await client.query('GRANT SELECT ON public.schema_migrations TO boarded_app');
    const recorded = await client.query('SELECT version, checksum FROM public.schema_migrations ORDER BY version');
    // A database ahead of this checkout, a removed migration or an edited applied
    // file is an error. Applied migrations must be an exact prefix, not a subset.
    for (let index = 0; index < recorded.rows.length; index += 1) {
      const row = recorded.rows[index];
      const source = migrations[index];
      if (!source || row.version !== source.version || row.checksum !== source.checksum) {
        throw new MigrationError('Applied migration history does not match this checkout; restore the matching files before proceeding.');
      }
    }
    const pending = migrations.slice(recorded.rows.length);
    for (const migration of pending) {
      applying = migration.version;
      await client.query(migration.sql);
      await client.query('INSERT INTO public.schema_migrations(version, checksum) VALUES ($1, $2)',
        [migration.version, migration.checksum]);
    }
    await client.query('COMMIT');
    inTransaction = false;
    for (const migration of pending) console.log(`Applied ${migration.version}`);
    console.log(pending.length ? `Committed ${pending.length} migration(s).` : 'Schema is up to date; checksums verified.');
  } catch (error) {
    if (inTransaction) await client.query('ROLLBACK').catch(() => {});
    if (error instanceof MigrationError) throw error;
    // Driver errors can contain hostnames, connection options or SQL values.
    // Keep credentials and database contents out of terminal/deployment logs.
    const code = typeof error?.code === 'string' && /^[A-Z0-9_]{1,32}$/.test(error.code)
      ? ` (${error.code})` : '';
    throw new MigrationError(`Migration failed${applying ? ` in ${applying}` : ''}${code}; transaction rolled back.`);
  } finally {
    await client.end().catch(() => {});
  }
}

try {
  await migrate();
} catch (error) {
  console.error(error instanceof MigrationError ? error.message : 'Unable to load migrations.');
  process.exitCode = 1;
}
