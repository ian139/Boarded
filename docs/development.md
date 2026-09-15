# Boarded development guide

Boarded is the standalone Next.js route-setting web app. The native PostgreSQL target uses same-origin server APIs, Better Auth sessions, and local filesystem uploads; it has no browser database credentials and no hosted/self-hosted Supabase setup path.

## Prerequisites and local setup

Use Node.js 22.18+ and npm, with PostgreSQL 18 in a separate disposable local cluster. The migration runner requires database `boarded`, its owner/login `boarded_migrator`, and the existing non-owner runtime role `boarded_app`; never point it at production. Give neither login superuser, create-role, create-database or bypass-RLS privileges, and do not make the runtime role a member of the migration role. Set separate passwords privately through the local administrator's `psql` `\password` command, not shell arguments. Then install dependencies and create a local-only environment file:

```sh
npm ci
cp .env.local.example .env.local
chmod 600 .env.local
```

Set server-only values in `.env.local` (example values are for a disposable local database only):

```dotenv
DATABASE_URL=postgresql://boarded_app:REPLACE_LOCAL_APP_PASSWORD@127.0.0.1:5432/boarded
APP_ORIGIN=http://localhost:3000
BETTER_AUTH_SECRET=REPLACE_WITH_A_LOCAL_RANDOM_SECRET
UPLOAD_DIR=/absolute/path/to/boarded-dev-uploads
SMTP_HOST=REPLACE_TLS_CAPTURE_HOST
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=REPLACE_CAPTURE_USER
SMTP_PASSWORD=REPLACE_CAPTURE_PASSWORD
SMTP_FROM=REPLACE_CAPTURE_SENDER
```

Create a separate private `.env.migration.local` containing only `DATABASE_MIGRATION_URL=postgresql://boarded_migrator:REPLACE_LOCAL_MIGRATOR_PASSWORD@127.0.0.1:5432/boarded` and set mode `0600`. Remove that migration variable from `.env.local` if the example includes it; the web process must not receive the schema-owner credential. Create the configured upload directory with mode `0700`, owned by the development account, outside `public` and the source checkout. Replace every example value with the actual disposable configuration.

Do not commit `.env.local`, put secrets in `NEXT_PUBLIC_*`, log credentials/cookies/tokens, or use a browser-provided owner/moderator value. For local signup, use a separately reviewed authenticated TLS mail-capture relay with nonempty credentials; never disable confirmation in order to make a flow appear to work.

Run the reviewed schema migrations with the separate migration identity, then start the app. The migration runner reads `process.env`; Node 22's env-file flag makes the local source explicit:

```sh
node --env-file=.env.migration.local scripts/migrate.mjs
npm run dev
```

If using the npm wrapper, export only `DATABASE_MIGRATION_URL` before `npm run db:migrate`; do not assume npm loads an environment file. Never print the connection value or leave it exported in the web server's environment.

The canonical migration script is `npm run db:migrate` (or the explicit Node invocation above). It must use `DATABASE_MIGRATION_URL`, an ordered migration ledger, and plain PostgreSQL migrations. Do not apply `supabase/migrations/001_initial_schema.sql` through `013_mobile_social.sql` to plain PostgreSQL; those files are retained historical requirements and reference Supabase-only Auth, Storage, roles, policies, and functions.

Production-shaped verification uses a separate HTTPS staging origin and the authenticated TLS capture relay, not the development HTTP origin. Follow [native operations](backend-self-hosting.md) to build/install and start `.next/standalone/server.js` with copied `public`/`.next/static`, bounded cache writes, private runtime configuration and the `/api/health` readiness check. The standalone production runtime enforces production configuration; do not use `NODE_ENV` tricks to bypass HTTPS or mail security.

## Browser routes and persistence

The main routes are `/`, `/editor`, `/profile`, `/settings`, `/login`, `/signup`, `/forgot-password`, `/reset-password`, and `/share/[token]`. Sharing remains `/share/[token]`; the server must enforce public visibility and atomically count eligible views.

On `/profile`, **Change profile** opens the avatar and username editor. Selecting a JPEG, PNG or WebP photo saves it immediately; **Save username** persists the handle separately. Successful changes appear on the page and after reopening or reloading. Username is a unique handle, not the authentication display name; renaming it does not change that display name.

New profiles receive compact generated handles of at most 21 characters (a sanitized prefix of up to 12 characters, a hyphen, and eight UUID hex characters). Existing handles, including long defaults and custom names, remain unchanged unless the user deliberately edits them. Usernames accept 1–80 ASCII letters, numbers, underscores or hyphens; a taken name leaves the typed draft available to correct.

Preserve these browser persistence names and semantics:

| Key | Purpose |
| --- | --- |
| `boarded-routes` | Cached and pending routes |
| `boarded-walls` | Walls and selected wall |
| `boarded-user` | Cached profile only, never auth or moderator authority |
| `boarded-draft` | Local editor draft |
| `boarded-storage-history` | Storage usage history |
| `boarded-board-theme` | Theme preference |
| `climbset-install-dismissed` | Install-prompt session state |

Storage is scoped to origin, browser profile, device, and (for session storage) tab lifetime. A path change on the same origin retains local state; a hostname/scheme/port change does not. Settings data clearing removes route/wall/draft cache, not account deletion. Same-origin HttpOnly auth cookies replace old Supabase sessions; `boarded-user` is only a cache. Logout/account switching must clear user-specific remote state without deleting local drafts.

Keep local-first behavior: signed-out drafts, local/default walls, route snapshots, `_createSyncPending`, and `_socialSyncPending` survive network failures. A retry is successful only after a committed server response; never display a local-only route as publicly shared. Preserve duplicate-ID ownership checks, optimistic rollback, serialized sync, and late-response guards across account changes.

## Server contract during development

All reads/writes/uploads use same-origin server handlers and derive identity from the validated session. The server validates ownership, parent visibility, moderator permissions, file content, and request fields; client local state and request `user_id` are not authority. Auth cookies require secure production settings, expiry/revocation, rotation on authentication, CSRF/origin protection, and rate limits. SMTP verification and recovery tokens are expiring and single-use; do not log them.

The data model preserves profiles (including `home_area`), walls, routes, holds/grades/snapshots, ascents, comments, likes, visibility, share tokens, and file metadata. Migration-013 records—`climbing_sessions`, `climb_attempts`, `session_posts`, timeline snapshots, likes/comments, meetups/attendees/comments, and social-media files—must remain in an approved schema/archive even though the standalone UI does not consume their social APIs.

Existing source data is not imported automatically. An approved conversion must export identity metadata, all rows, privileged assignments, migration history, and every referenced file byte; stage-import while preserving IDs, timestamps, ownership, relationships, visibility, share tokens, and checksums; map old image URLs to new file IDs; and verify password-hash compatibility. Otherwise require secure recovery/re-enrollment. Existing Supabase sessions cannot be reused. Keep the old origin available for browser-draft recovery and old share links during cutover.

## Checks and troubleshooting

Run only checks appropriate to the change; these commands are not deployment evidence:

```sh
npm run lint
npm test
npm run build
```

For runtime acceptance, exercise `/api/health`, signup confirmation through the reviewed TLS mail-capture relay, login/reload/logout, profile and home-area updates, wall/file upload, route CRUD and sharing, social interactions, account switching, offline drafts/retries, and authorization/privacy boundaries. Also rehearse backup and isolated restore with the exact source release before inviting users. A green build or test command does not prove deployment, migration, mail delivery, or recovery.

Common failures:

- **Database connection:** verify local PostgreSQL, database name, role grants, and `DATABASE_URL`; do not switch to a Supabase URL or grant public access.
- **Migration failure:** stop at the first failed version, inspect the ledger/database, and fix deliberately; never apply later versions or historical Supabase SQL.
- **Auth/mail failure:** inspect the local sink and SMTP configuration; do not disable confirmation or print tokens.
- **Health failure:** inspect bounded server logs and `/api/health`; a running process is not readiness.
- **Old drafts/share links missing:** check origin continuity and retained source records/files; changing environment variables alone does not migrate data or browser state.
