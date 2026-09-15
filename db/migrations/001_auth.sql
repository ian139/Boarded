-- PostgreSQL 15+, run only by scripts/migrate.mjs as boarded_migrator.
-- Provision boarded (owned by boarded_migrator) and the distinct boarded_app login
-- beforehand. Neither role needs SUPERUSER, CREATEDB, CREATEROLE or BYPASSRLS.
-- Schema derived from installed better-auth 1.7.4:
-- @better-auth/core/src/db/get-tables.ts and better-auth/dist/db/get-migration.mjs.
-- Configuration: direct pg pool, advanced.database.generateId='uuid', no plugins,
-- rateLimit.storage='database', no field/model overrides or secondary storage.
-- This is committed DDL, not a request to run Better Auth migrations at startup.
-- The library supplies emailVerified and rate-limit values; its CREATE TABLE
-- generator does not emit SQL defaults for those non-date fields.
REVOKE CREATE ON SCHEMA public FROM PUBLIC, boarded_app;
REVOKE CREATE, TEMPORARY ON DATABASE boarded FROM PUBLIC, boarded_app;
GRANT CONNECT ON DATABASE boarded TO boarded_app;
GRANT USAGE ON SCHEMA public TO boarded_app;
ALTER DEFAULT PRIVILEGES FOR ROLE boarded_migrator IN SCHEMA public
  REVOKE ALL ON TABLES FROM PUBLIC, boarded_app;
ALTER DEFAULT PRIVILEGES FOR ROLE boarded_migrator IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

CREATE TABLE public."user" (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  "emailVerified" BOOLEAN NOT NULL,
  image TEXT,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE public."session" (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  "expiresAt" TIMESTAMPTZ NOT NULL,
  token TEXT NOT NULL UNIQUE,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ NOT NULL,
  "ipAddress" TEXT,
  "userAgent" TEXT,
  "userId" UUID NOT NULL REFERENCES public."user"(id) ON DELETE CASCADE
);
CREATE INDEX "session_userId_idx" ON public."session"("userId");
CREATE TABLE public.account (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  "accountId" TEXT NOT NULL,
  "providerId" TEXT NOT NULL,
  "userId" UUID NOT NULL REFERENCES public."user"(id) ON DELETE CASCADE,
  "accessToken" TEXT,
  "refreshToken" TEXT,
  "idToken" TEXT,
  "accessTokenExpiresAt" TIMESTAMPTZ,
  "refreshTokenExpiresAt" TIMESTAMPTZ,
  scope TEXT,
  password TEXT,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ NOT NULL
);
CREATE INDEX "account_userId_idx" ON public.account("userId");
CREATE TABLE public.verification (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  identifier TEXT NOT NULL,
  value TEXT NOT NULL,
  "expiresAt" TIMESTAMPTZ NOT NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX verification_identifier_idx ON public.verification(identifier);
CREATE TABLE public."rateLimit" (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  count INTEGER NOT NULL,
  "lastRequest" BIGINT NOT NULL
);

-- A moderator is assigned by a trusted operator, never by a signup/profile field.
-- Example (bound parameter through an operator tool):
-- INSERT INTO public.user_roles(user_id, role) VALUES ($1, 'moderator');
CREATE TABLE public.user_roles (
  user_id UUID PRIMARY KEY REFERENCES public."user"(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role = 'moderator'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
REVOKE ALL ON public."user", public."session", public.account,
  public.verification, public."rateLimit", public.user_roles FROM PUBLIC, boarded_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON public."user", public."session",
  public.account, public.verification, public."rateLimit" TO boarded_app;
GRANT SELECT ON public.user_roles TO boarded_app;
