import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
import pg from 'pg';
import ts from 'typescript';
import type { PoolClient } from 'pg';
import type { Actor } from './http';
import type * as Resources from './resources';

const require = createRequire(import.meta.url);
const filename = new URL('./resources.ts', import.meta.url);
const source = ts.transpileModule(readFileSync(filename, 'utf8'), {
  fileName: filename.pathname,
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

// Match the store tests' loader: exercise the actual module, isolating unrelated
// Next/auth dependencies and controlling only the random candidate source.
function loadResources(nextUUID: () => string = randomUUID): typeof Resources {
  const mocks: Record<string, unknown> = {
    'server-only': {},
    'node:crypto': { randomUUID: nextUUID },
    './db': {},
    './http': { endpoint: (handler: unknown) => handler },
    './files': {},
    './validation': {},
  };
  const module = { exports: {} };
  runInNewContext(source, {
    module,
    exports: module.exports,
    require: (name: string) => Object.hasOwn(mocks, name) ? mocks[name] : require(name),
  }, { filename: filename.pathname });
  return module.exports as typeof Resources;
}

function actor(displayName: string): Actor {
  return { id: randomUUID(), email: 'profile@example.test', displayName, createdAt: '2026-01-01T00:00:00Z', isModerator: false };
}

// Use a disposable PostgreSQL database with CREATE SCHEMA permission. This test
// creates/drops only its unique schema; it never touches the app's public tables.
// TEST_DATABASE_URL=... node --test lib/server/profile-naming.test.ts
test('profile allocation preserves identity and survives occupied candidates', {
  skip: process.env.TEST_DATABASE_URL ? false : 'Requires TEST_DATABASE_URL for disposable PostgreSQL',
  timeout: 30_000,
}, async (t) => {
  const schema = `profile_naming_${randomUUID().replaceAll('-', '')}`;
  const database = new pg.Pool({
    connectionString: process.env.TEST_DATABASE_URL,
    max: 4,
    options: `-c search_path=${schema} -c statement_timeout=10000`,
  });
  t.after(async () => {
    try {
      await database.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    } finally {
      await database.end();
    }
  });
  await database.query(`CREATE SCHEMA ${schema}`);
  await database.query('CREATE TABLE profiles (id uuid PRIMARY KEY, username text NOT NULL UNIQUE, full_name text NOT NULL)');

  async function transaction<T>(operation: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await database.connect();
    try {
      await client.query('BEGIN');
      const result = await operation(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  await t.test('occupied compact candidates are retried without aborting the transaction', async () => {
    const user = actor('Very Long Climber Name');
    const occupied = actor('Other climber');
    await database.query('INSERT INTO profiles VALUES($1,$2,$3)', [occupied.id, 'very-long-cl-aaaaaaaa', occupied.displayName]);
    const candidates = ['aaaaaaaa-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000002'];
    const { ensureProfile } = loadResources(() => {
      const next = candidates.shift();
      assert.ok(next, 'Allocation must stop after the first available candidate');
      return next;
    });
    const created = await transaction(client => ensureProfile(client, user));
    assert.equal(created.username, 'very-long-cl-bbbbbbbb');
    assert.match(created.username, /^[a-z0-9_-]{1,21}$/);
    assert.equal(created.full_name, user.displayName);
    assert.equal((await database.query('SELECT username FROM profiles WHERE id=$1', [occupied.id])).rows[0].username, 'very-long-cl-aaaaaaaa');
    assert.equal((await transaction(client => ensureProfile(client, user))).username, created.username);
  });

  await t.test('existing custom and full-UUID handles are returned without renaming', async () => {
    const { ensureProfile } = loadResources(() => { throw new Error('Existing profiles must not need another candidate'); });
    for (const username of ['My_Custom-42', `old-climber-${randomUUID()}`]) {
      const user = actor('Changed authentication display name');
      await database.query('INSERT INTO profiles VALUES($1,$2,$3)', [user.id, username, 'Original full name']);
      const existing = await transaction(client => ensureProfile(client, user));
      assert.equal(existing.username, username);
      assert.equal(existing.full_name, 'Original full name');
      assert.equal((await database.query('SELECT username FROM profiles WHERE id=$1', [user.id])).rows[0].username, username);
    }
  });

  await t.test('concurrent first access returns one stable profile and distinct users get unique handles', async () => {
    const { ensureProfile } = loadResources();
    const first = actor('Same Climber');
    const second = actor('Same Climber');
    const results = await Promise.all([first, first, first, second].map(user => transaction(client => ensureProfile(client, user))));
    assert.equal(results[0].username, results[1].username);
    assert.equal(results[0].username, results[2].username);
    assert.notEqual(results[0].username, results[3].username);
    for (const result of results) assert.match(result.username, /^[a-z0-9_-]{1,21}$/);
    const rows = await database.query('SELECT id,username FROM profiles WHERE id=ANY($1::uuid[])', [[first.id, second.id]]);
    assert.equal(rows.rowCount, 2);
    assert.equal((await transaction(client => ensureProfile(client, first))).username, results[0].username);
  });

  await t.test('names without ASCII letters or digits use a compact fallback', async () => {
    const { ensureProfile } = loadResources(() => 'cccccccc-0000-4000-8000-000000000003');
    const profile = await transaction(client => ensureProfile(client, actor('山 !')));
    assert.equal(profile.username, 'climber-cccccccc');
  });

  await t.test('exhausted candidates fail explicitly without creating a long fallback', async () => {
    const occupied = actor('Occupied');
    const user = actor('Blocked');
    await database.query('INSERT INTO profiles VALUES($1,$2,$3)', [occupied.id, 'blocked-dddddddd', occupied.displayName]);
    let attempts = 0;
    const { ensureProfile } = loadResources(() => {
      attempts++;
      if (attempts > 8) throw new Error('Allocation exceeded its bounded retry allowance');
      return 'dddddddd-0000-4000-8000-000000000004';
    });
    await assert.rejects(transaction(client => ensureProfile(client, user)), /Unable to allocate a unique profile username/);
    assert.equal(attempts, 8);
    assert.equal((await database.query('SELECT id FROM profiles WHERE id=$1', [user.id])).rowCount, 0);
  });
});
