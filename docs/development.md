# Boarded development guide

Boarded is the standalone legacy climbing route-setting web app. The Next.js app lives at the repository root; no native app, journal shell, or 3D landing runtime is shipped here.

## Prerequisites

- Node.js 22.18 or newer and npm. Next.js 16 requires 20.9+, but the utility test command also needs Node's built-in TypeScript support.
- The pinned web versions are Next.js `16.1.1` and React `19.1.0`.
- A hosted Supabase project or the independent self-hosted backend for cloud-backed features.
- Python 3 and Docker only for the optional disposable local RLS harness below; deployment prerequisites are documented separately.

The npm workspace contains the route setter and `packages/shared`.

<a id="web"></a>
## Web setup

```bash
npm install
cp .env.local.example .env.local
```

Set the two public browser variables in `.env.local`, then run `npm run dev` and open <http://localhost:3000>.

| Variable | Meaning | Handling |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Hosted Supabase project URL or self-hosted API gateway URL | Must address the intended backend and be reachable from the browser. |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | That backend's public anonymous/publishable key | Used with normal user sessions and RLS; never substitute a service-role key. |

Keep `.env.local` local. Never put privileged credentials in tracked files, browser configuration, screenshots, or logs. Restart the development server after changing configuration; rebuild production when changing `NEXT_PUBLIC_*` values.

### Public routes

- `/` — walls and routes
- `/editor` — route editor
- `/profile` — identity, route statistics, and climb history
- `/settings` — preferences and local data controls
- `/login` and `/signup` — account access
- `/share/[token]` — shared route viewer

The route setter is mounted at the origin root, not under `/board`. There is no `/app` journal application.

## Exact npm commands

```bash
npm install
npm run dev
npm run build
npm start
npm run lint
npm test
```

`npm start` serves an existing production build; run `npm run build` first. `npm test` runs the shared utility and legacy web utility tests, not a journal test suite.

<a id="supabase"></a>
## Supabase setup and migrations

### Hosted Supabase

1. Create or select the intended hosted project. Use its URL and public anonymous/publishable key for the browser variables above.
2. On a new backend, apply every checked-in migration from `supabase/migrations/001_initial_schema.sql` through `013_mobile_social.sql` **once, in numeric order**, using the Dashboard SQL Editor or a separately maintained linked CLI workflow. For an existing backend, inspect its applied history and apply only missing migrations in order.
3. Configure Auth's site URL and permitted redirects for the actual web origin, including the localhost origin when developing. Configure email delivery and confirmation for signup rather than disabling confirmation to work around missing mail.
4. Keep the same project for existing users, route records, Storage objects, and share tokens unless undertaking a separate, deliberate backend migration.

The whole 001–013 chain is retained byte-for-byte. Although this client no longer includes the journal/native experience, the legacy profile upsert writes `home_area`, which migration 013 adds. Trimming the chain breaks the profile contract; historical schema is not evidence that the removed clients still ship.

There is no `supabase/config.toml` in this repository. This checkout alone does not configure `supabase start`; a separately linked CLI workflow must maintain its own configuration and credentials outside tracked source.

### Self-hosted backend

The independent `deploy/self-hosted` tools retain the Boarded deployment identity. They operate PostgreSQL, Auth, PostgREST, Storage, and an allowlisted loopback gateway. Follow [self-hosted backend operations](backend-self-hosting.md) for secret generation, bootstrap, email setup, health, backups, and destructive restore procedures. Point the web client at the browser-reachable gateway and its public `ANON_KEY`, never `SERVICE_ROLE_KEY`.

This repository split performs **no data migration**: it does not provision a backend, apply SQL, move users or objects, restore a backup, change a deployment, or transfer browser state.

## Persistence and origins

The existing browser persistence names remain unchanged:

| Key | State |
| --- | --- |
| `boarded-routes` | Persisted route cache and local/pending routes |
| `boarded-walls` | Persisted walls and selected wall |
| `boarded-user` | Cached profile only, not authentication or moderator status |
| `boarded-draft` | Local editor hold draft |
| `boarded-storage-history` | Local storage usage history |
| `boarded-board-theme` | Route-setter theme preference |
| `climbset-install-dismissed` | Install-prompt dismissal in session storage |

Browser-local storage is scoped to the origin (scheme, hostname, and port), browser profile, and device, not the URL pathname. Moving from `/board` to `/` on the same origin leaves those keys accessible; changing origin does not transfer them. Session storage also follows the tab/session lifetime. Settings' Clear Data removes `boarded-routes`, `boarded-walls`, and `boarded-draft`; it is not an account deletion or sign-out operation.

The Supabase browser client retains the `boarded-auth` storage key with session persistence, automatic token refresh, and URL session detection enabled. Auth storage is managed by `@supabase/ssr`; it is not the cached `boarded-user` profile. Authentication comes from the backend session. Retaining the origin, backend, and configuration avoids intentionally changing that storage contract, but does not guarantee an expired or revoked session remains signed in.

Signing in can synchronize eligible local routes and retry pending creation for the matching owner. Ordinary cached remote routes are not a backend-migration export, and local-only walls are not automatically uploaded. Changing backend requires deliberate handling of Auth users, routes, profile records, Storage objects and URLs, and reauthentication; changing the browser variables alone does not migrate any of them.

Sharing uses `${window.location.origin}/share/[token]`. A route must be synchronized to the backend and public before others can load it; a token present only in local state is insufficient. The shared viewer queries the backend's public route/token record, not the sender's browser cache. Existing links retain their original hostname: preserve that origin or separately arrange its routing, and preserve the backend records and wall images. A new origin/backend does not repair old links automatically.

The web app manifest launches at `/`. Its explicit `id: "/app"` preserves the previously implicit installed-PWA identity; this is an identifier, not a live route or redirect. Existing theme and authentication storage keys are unchanged. The standalone service-worker cache namespace replaces the former mixed-product shell and uses `/` as the offline navigation fallback.

## Optional local RLS ownership harness

The retained security harness requires a separately started disposable local Supabase stack:

```bash
python3 supabase/tests/rls_ownership_harness.py
```

Its defaults are `http://127.0.0.1:54321` and Docker container `supabase_db_boarded-supabase`. Optional overrides are:

```bash
BOARDED_LOCAL_SUPABASE_URL=http://127.0.0.1:54321 \
BOARDED_LOCAL_DB_CONTAINER=supabase_db_boarded-supabase \
python3 supabase/tests/rls_ownership_harness.py
```

The harness refuses non-loopback URLs and container names without the `supabase_db_` prefix. It uses normal local Auth JWTs and Docker Postgres fixture setup/cleanup, not a service-role key. It intentionally refuses the independent self-hosted deployment's `boarded-supabase-db-1` container. Never point it at production or rename containers to bypass its guards.

## Validation

Run checks relevant to the change:

```bash
npm run lint
npm test
npm run build
```

Exercise the affected browser routes and interactions as well. The Python harness above is conditional on a disposable local stack; a missing local stack is not permission to target a remote project.

<a id="repository-map"></a>
## Repository map

- `app/` — Next.js root routes, layouts, and global styles.
- `components/` — route-setting UI and shared components.
- `lib/` — Supabase client, stores, hooks, utilities, and tests.
- `packages/shared/` — shared route-setting TypeScript types and utilities.
- `public/` — static assets, default wall photo, and installable web app assets.
- `supabase/migrations/` — immutable ordered schema, policy, RPC, and Storage history (001–013).
- `supabase/tests/` — local-only security harness.
- `deploy/self-hosted/` — independent backend operations tooling.
- `.env.local.example` — public variable-name template; `.env.local` stays local.

## Troubleshooting

- **Data or Auth fails:** check the intended URL and public key, backend reachability, and migration history. Restart development or rebuild production after changing browser configuration.
- **Signup succeeds but confirmation never arrives:** inspect the backend mail configuration; self-hosted Auth needs a real SMTP relay before signup is offered.
- **`npm start` fails:** build first; `next start` only serves a generated production build.
- **RLS harness refuses to run:** use a disposable loopback stack and supported container name; keep its guards intact.
- **Migration fails:** stop at the first failure, inspect the backend state, and restore the required order before continuing. Do not blindly rerun later migrations.
