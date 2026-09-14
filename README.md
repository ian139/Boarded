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

Use Node.js 22.18 or newer and npm; the utility tests use Node's built-in TypeScript support. Cloud-backed features require a Supabase-compatible backend.

```bash
npm install
cp .env.local.example .env.local
npm run dev
```

Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in your local copy, then open <http://localhost:3000>. Only use a public anonymous/publishable key in the browser; never commit `.env.local` or expose a service-role key.

## Backend and data continuity

Use a hosted Supabase project or the independent deployment tools in `deploy/self-hosted`. Follow the [development guide](docs/development.md#supabase) for the hosted setup and the [self-hosted backend guide](docs/backend-self-hosting.md) for operations.

The complete SQL history, migrations 001–013, is retained unchanged. The legacy profile upsert writes `home_area`, introduced in migration 013; removing the later migrations would break that contract. Apply the whole chain once in numeric order on a new backend. This repository split performs no data migration and does not change the default Boarded deployment identity.

Browser-local data and sessions do not automatically move to a different origin or backend. Keep the existing origin and backend for continuity; see [persistence and origins](docs/development.md#persistence-and-origins) before changing either. Shared links also depend on their original hostname and backend records.

## Documentation

- [Web setup and commands](docs/development.md#web)
- [Supabase migrations](docs/development.md#supabase)
- [Persistence and origins](docs/development.md#persistence-and-origins)
- [Validation](docs/development.md#validation)
- [Repository map](docs/development.md#repository-map)
- [Self-hosted backend operations](docs/backend-self-hosting.md)

## Releases

Read the [latest release notes](https://github.com/Ian139/Boarded/releases/latest) or [browse all releases](https://github.com/Ian139/Boarded/releases).
