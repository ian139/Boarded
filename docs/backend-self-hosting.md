# Boarded native PostgreSQL operations

**Deployment NOT YET verified.** These are implemented operations for Ubuntu 26.04, native PostgreSQL 18, Node 22.18+, Caddy, and the standalone Next.js server. This packet did not execute a deployment, migration, backup, or restore. There is no hosted or self-hosted Supabase setup path.

## Prerequisites and administrator boundary

Use the existing PostgreSQL/Node installation; do not reinstall unrelated services or touch Docker monitoring. PostgreSQL stays on loopback/socket, port 5432. The helper's administrative `psql`, `pg_dump`, and `pg_restore` connections use the local `postgres` OS account and peer authentication. Runtime connections use SCRAM over loopback. Review HBA ordering for the intended database/roles; never enable `trust` or public database access. Restore databases/roles need separately scoped loopback HBA access as well.

The supplied server inventory reports PostgreSQL 18 listening on loopback and existing Node 22. General sudo currently needs interactive administrator authentication; approved package/service wrappers do **not** authorize creating accounts/directories, changing database roles, or installing this helper. Obtain a reviewed administrator session or narrowly approved, root-owned operations helper before these steps. Do not bypass sudo policy. Verify `/usr/bin/node`, `/usr/bin/npm`, Python 3, Git, PostgreSQL 18 clients, systemd, `useradd`, and `runuser` are installed at the helper/unit paths.

From the reviewed repository root, the administrator installs the helper outside the as-yet nonexistent application directory. Inspect an existing destination before replacing it; never overwrite an unrelated program:

```sh
sudo install -o root -g root -m 0755 \
  deploy/native-postgres/boarded-ops /usr/local/sbin/boarded-ops
```

All privileged invocations below use that installed, root-owned helper, not a deploy-user-writable script under sudo. Parameters shown as examples must be chosen for this host. Secrets must never be placed in arguments, Git, screenshots, or logs.

## Initialize an empty target

```sh
sudo /usr/local/sbin/boarded-ops initialize \
  --origin https://boarded.example.com \
  --confirm initialize-empty-boarded
```

Replace the example origin first. Initialization refuses existing Boarded database/roles, accounts, configuration, state, cache, and release directories. It is not a migration/import command. Partial failures preserve what was created: inspect and reconcile as administrator, never delete data to force a retry.

| Location/identity | Purpose |
| --- | --- |
| `boarded` OS account | Non-login application user, no sudo |
| `boarded-migrate` OS account | Separate non-login migration process identity |
| `boarded-restore` OS account | Isolated restore runtime, cannot read production uploads |
| PostgreSQL `boarded_migrator` | Owns database `boarded` and schema migrations; no superuser/create-role/create-db rights |
| PostgreSQL `boarded_app` | Explicit runtime grants, no object ownership or migration-role membership |
| `/srv/boarded/releases/<full-git-sha>` | Root-owned immutable code, build output, dependencies and migration runner |
| `/srv/boarded/current` | Atomically replaced active-release symlink |
| `/var/lib/boarded/uploads` | Durable `boarded`-owned mode-0700 uploads, outside the web root |
| `/var/cache/boarded` | Disposable bounded writable Next cache |
| `/etc/boarded/runtime.env` | Root-owned mode-0600 application environment |
| `/etc/boarded/migration.env` | Root-owned mode-0600 migration environment, never loaded by the web service |

The runtime environment contains `DATABASE_URL`, `APP_ORIGIN`, `BETTER_AUTH_SECRET`, `UPLOAD_DIR`, and `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`. Replace generated SMTP placeholders through a private administrator editor. `SMTP_PORT` accepts any integer from 1 through 65535, including high-port relays. `SMTP_SECURE` is explicitly `true` for implicit TLS or `false` for required STARTTLS; authenticated, certificate-validated TLS remains mandatory in both cases. Ports 465/587 are examples, not an allowlist. Production `APP_ORIGIN` must be the canonical HTTPS origin. Never bypass email verification to compensate for missing mail.

The migration file contains only `DATABASE_MIGRATION_URL`. The helper accepts simple `NAME=value` or shell-quoted single-line values, with no expansion; generated values are double-quoted. Keep private files root-owned 0600 and every ancestor root-controlled, non-symlink and non-group/world-writable. Do not put private values in `NEXT_PUBLIC_*`.

## Build and install a release

Initialization must precede the first `install-release`. Build as an unprivileged deploy account, on Linux for the target architecture; do not copy macOS dependencies. The parent of the new build directory must already exist and be deploy-user writable:

```sh
SOURCE="$PWD"
RELEASE=$(git rev-parse HEAD)
BUILD="$HOME/boarded-build-$RELEASE"
/usr/local/sbin/boarded-ops build-release "$SOURCE" "$BUILD"
sudo /usr/local/sbin/boarded-ops install-release "$BUILD" \
  --confirm "install-$RELEASE"
```

Build uses committed Git state only, `npm ci`, `npm run build`, and `NEXT_PUBLIC_BUILD_ID` equal to the commit SHA. No production credentials are supplied. It requires `.next/standalone/server.js`, copies `public` and `.next/static` into standalone output, and connects only its disposable `.next/cache` to the fixed cache directory. Full source/dependencies remain available for the explicit migration runner.

Installation checks Linux/architecture/Node-major compatibility, copies into private root staging under the operation lock, normalizes ownership/modes, and rejects dependencies linked outside the immutable tree except the exact bounded cache link. Only complete releases are published. Existing release IDs are never overwritten; failed private staging directories are retained for inspection.

## Install units, migrate, activate, publish

Review `deploy/native-postgres/boarded.service`, `boarded-restore@.service`, and `Caddyfile`. Confirm destination units are absent or the explicitly approved Boarded units before these administrator installation commands:

```sh
sudo install -o root -g root -m 0644 deploy/native-postgres/boarded.service \
  /etc/systemd/system/boarded.service
sudo install -o root -g root -m 0644 deploy/native-postgres/boarded-restore@.service \
  /etc/systemd/system/boarded-restore@.service
sudo systemctl daemon-reload
```

For an initial empty database there is no active release to back up. **Before an upgrade**, take the coherent backup below and coordinate a write freeze. The migration helper explicitly stops the service, including pending automatic restarts, and leaves it stopped; migrations never run from the web service startup:

```sh
sudo /usr/local/sbin/boarded-ops migrate "$RELEASE" --confirm "migrate-$RELEASE"
sudo /usr/local/sbin/boarded-ops activate "$RELEASE" --confirm "activate-$RELEASE"
sudo /usr/local/sbin/boarded-ops health
```

`migrate` runs `npm run db:migrate` as `boarded-migrate` with the migration-only environment. It applies the plain-Postgres `db/migrations` ledger, not historical `supabase/migrations/001`–`013`. Never apply that historical platform-dependent SQL to plain PostgreSQL.

The production service loads private configuration through systemd, runs `/usr/bin/node .next/standalone/server.js` as `boarded`, binds `127.0.0.1:3000`, and permits writes only to uploads/cache and private temporary storage. It cannot read the migration file or isolated restore state. Activation changes `current`, restarts the unit and waits for `/api/health` HTTP 200. A failed readiness check does not roll back SQL or silently switch code; inspect bounded `journalctl -u boarded.service` output and recover deliberately.

Merge the reviewed Caddy site into the existing configuration, replacing only its example hostname. Do not replace other sites. Validate the merged configuration before reload:

```sh
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl reload caddy
sudo systemctl enable boarded.service
```

Caddy must route UI, API, and authorized file reads to the same application origin; never use `file_server` on uploads. The template limits request bodies and does not enable access logs containing auth URL tokens. Confirm DNS, certificates, firewall and external HTTPS/mail independently. Keep ports 3000/5432 and Caddy administration private. A successful local health check is not external deployment acceptance.

Keep `header_up X-Real-IP {remote_host}` inside every Boarded `reverse_proxy` block, including a staging proxy. Better Auth trusts only `x-real-ip`; Caddy must overwrite a supplied header with its actual peer address, otherwise clients can spoof rate-limit identities or all requests without the header share one bucket. Do not publish Next.js directly. An additional CDN/tunnel/proxy requires a separately reviewed trusted-proxy configuration; never forward arbitrary client IP headers as authority.

## Coherent backups

Create a root-controlled backup parent first, on storage with enough free space. The backup destination itself must be new. Example:

```sh
sudo install -d -o root -g root -m 0700 /srv/boarded-backups
BACKUP="/srv/boarded-backups/boarded-$(date -u +%Y%m%dT%H%M%SZ)"
sudo /usr/local/sbin/boarded-ops backup "$BACKUP" \
  --confirm pause-boarded-and-backup
```

Backup, install, migrate, activate and restore share a kernel `flock` on `/etc/boarded/operation.lock`. Freeze out-of-band administrative/import writers too: the helper can quiesce its application, not arbitrary privileged writers. A transitional/automatically restarting unit is rejected; wait for a stable state or explicitly stop it first.

Backup stops the application, sets `boarded_app NOLOGIN`, terminates its database sessions, captures a custom-format database dump and matching upload tree, and records file/database SHA-256 checksums, release identity, configuration checksum and exact runtime object grants. It then restores login and restarts the service only if it was previously active, with a readiness wait. It does not copy a running PostgreSQL data directory.

Incomplete and completed destinations are retained even on failure. Never restore a set containing `INCOMPLETE`. If killed while the runtime role is `NOLOGIN`, an administrator must confirm no operation/writer remains, inspect the preserved set/service/process state, and only then restore `ALTER ROLE boarded_app LOGIN;` through local `psql` and decide whether to restart. The kernel releases the lock on process exit; deleting its file is not a recovery procedure.

Hashes detect corruption, **not authenticity**. Restore only trusted, root-controlled backups transported/stored with separate authentication and encryption. Never run an untrusted SQL dump even if its accompanying hashes match. Keep encrypted off-host copies, retention/freshness alerts, and protected escrow of runtime/migration secrets, systemd/Caddy configuration, exact release/lockfile/Node version and recovery records. Secrets and cluster-wide role definitions are not in the payload; isolated restore explicitly recreates least-privilege roles. A local copy on the same disk is not disaster recovery.

## Isolated restore drill

Install the backup's exact release SHA first; restore refuses a missing/incomplete release. Prepare `/etc/boarded/restore-drill.env` privately, root-owned 0600. It must contain `APP_ORIGIN` for a separate HTTPS staging origin, and `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` for an independently reviewed **authenticated TLS mail-capture relay that does not deliver to real recipients**. Both origin and SMTP hostname must differ from production. Ports 1–65535 are supported; explicit `SMTP_SECURE=false` requires STARTTLS (for example, an authenticated capture relay on 1587), while `true` requires implicit TLS. Certificate validation and credentials remain mandatory; there is no insecure sink or `NODE_ENV` bypass.

```sh
RESTORE=boarded_restore_drill01
sudo /usr/local/sbin/boarded-ops restore-isolated "$BACKUP" "$RESTORE" \
  --runtime-env /etc/boarded/restore-drill.env \
  --confirm "create-isolated-$RESTORE"
```

Names must be `boarded_restore_` plus 1–24 lowercase letters, digits or underscores. The command verifies trusted custody, hashes/inventory, release and configuration before creating a new database, owner/runtime roles, and upload subtree. It restores original runtime privileges without broadening ledger/moderator/retained-schema access, revokes default public function execution, generates a fresh auth secret and writes private isolated environment files. It creates `/var/lib/boarded/restore/$RESTORE/release` itself, pointing at the exact installed release. Existing database/roles/path are never overwritten; partial results remain marked `INCOMPLETE`.

No service is started and no production DNS/current symlink is changed. After reviewing scoped HBA access, private HTTPS staging routing/access controls and actual mail capture, start one drill at a time:

```sh
sudo systemctl start "boarded-restore@$RESTORE.service"
```

The separate `boarded-restore` account binds loopback 3100, uses isolated uploads/cache, cannot read production uploads/configuration, and does not auto-restart. Validate staging `/api/health`, login/verification/recovery, profiles, route/wall/file persistence, public/private sharing, exact row/reference/checksum counts and retained data. Fresh secrets mean old sessions must not be assumed reusable. Stop the drill when complete; no automatic database/files deletion is provided. Do not run the production-name migration runner against a restore database.

## Existing-data conversion and rollback

These tools restore their own native backup format, not a Supabase export or browser state. Existing source data requires explicitly approved, purpose-built conversion: export identity metadata, every application and migration-013 table, privileged assignments, schema history, and every referenced uploaded byte; stage-import with IDs/FKs, timestamps, ownership, privacy, grades/holds, comments/ascents/likes and share tokens preserved; reconcile counts and checksums; record old-URL to new-file mappings. Verify password-hash compatibility through the maintained auth library or require secure recovery. Existing platform sessions are not transferable; signup with an existing email is not ownership proof.

Preserve the old origin for browser-draft recovery and route old share hostnames/paths deliberately. Retain migration-013 sessions, attempts, posts/timeline snapshots, likes/comments, meetups/attendees/comments and social-media files in conversion or an explicitly approved restorable archive; do not silently drop or expose private timelines.

At cutover freeze all source writes/uploads, take a final coherent export, reconcile it and obtain operator acceptance. Retain prior database/files/settings/release for the acceptance window. After new writes, rollback requires reviewed reverse conversion or an explicitly approved recovery point; never blindly down-migrate, run the old Supabase binary on plain PostgreSQL, overwrite production during a drill, or leave two writable backends.
