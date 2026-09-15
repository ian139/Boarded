<div align="center">

<h1>Boarded</h1>

<p><strong>Set, save, and share climbing routes.</strong></p>

<p>
  <a href="https://climbing-app-ashy.vercel.app">Open the web app</a> ·
  <a href="docs/development.md">Development guide</a> ·
  <a href="https://github.com/Ian139/Boarded/releases">Releases</a>
</p>

</div>

## About

Boarded is the standalone legacy climbing route setter: a Next.js web app for placing holds on wall photos, saving walls and routes, logging climbs, and sharing routes. This repository does not include the journal app, native iOS app, or 3D landing experience.

### Routes

| Path | Purpose |
| --- | --- |
| `/` | Browse walls and routes |
| `/editor` | Create and edit routes |
| `/profile` | Identity, route statistics, and climb history |
| `/settings` | Preferences and local data controls |
| `/login` | Sign in |
| `/signup` | Create an account |
| `/share/[token]` | View a shared route |

## Local development

Use Node.js 22.18 or newer, npm, and a disposable local PostgreSQL 18 cluster. Server-backed features use the same-origin Boarded API, Better Auth sessions, and persistent uploaded files—not Supabase.

```bash
npm ci
cp .env.local.example .env.local
```

Configure the server-only runtime values in `.env.local` and separate migration credentials in `.env.migration.local` as described in the [development guide](docs/development.md#prerequisites-and-local-setup). Never commit these files or expose database/auth/SMTP secrets through browser configuration. Once the disposable database, uploads directory, and TLS mail-capture configuration are ready:

```bash
node --env-file=.env.migration.local scripts/migrate.mjs
npm run dev
```

Open <http://localhost:3000>.

## Backend and data continuity

Deploy with native PostgreSQL, persistent local uploads, systemd, and Caddy using `deploy/native-postgres`. Follow the [hosting setup](docs/hosting-setup.md) and [native backend operations](docs/backend-self-hosting.md) for the exact administrator, configuration, release, migration, backup, and isolated-restore procedures. The target is a fresh database; deployment remains unverified until the documented runtime acceptance is completed.

The deployment migration runner applies the new plain-PostgreSQL `db/migrations` chain with a checksummed ledger. Historical `supabase/migrations/001`–`013` remain a requirements/data-preservation reference, **not SQL to apply to plain PostgreSQL**. Fresh installation performs no old-platform import; existing identities, records, uploads, or retained historical data require separately approved conversion or a restorable archive rather than silent deletion.

Browser-local drafts do not automatically move to a different origin or backend, and former platform sessions are not transferable to the new authentication system. Preserve the origin for draft recovery and arrange old share-hostname/record/file continuity deliberately; see [browser routes and persistence](docs/development.md#browser-routes-and-persistence) before changing the origin.

## Documentation

- [Web setup and commands](docs/development.md#prerequisites-and-local-setup)
- [Database setup and inexpensive hosting](docs/hosting-setup.md)
- [Database migrations and deployment](docs/backend-self-hosting.md#install-units-migrate-activate-publish)
- [Browser routes and persistence](docs/development.md#browser-routes-and-persistence)
- [Checks and troubleshooting](docs/development.md#checks-and-troubleshooting)
- [Native backend operations](docs/backend-self-hosting.md)

## Releases

Read the [latest release notes](https://github.com/Ian139/Boarded/releases/latest) or [browse all releases](https://github.com/Ian139/Boarded/releases).
