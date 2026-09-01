-- Runs after the retained upstream roles.sql without modifying the pinned blob.
\set authenticator_password `printf '%s' "$AUTHENTICATOR_DB_PASSWORD"`
\set auth_password `printf '%s' "$SUPABASE_AUTH_ADMIN_PASSWORD"`
\set storage_password `printf '%s' "$SUPABASE_STORAGE_ADMIN_PASSWORD"`
\set functions_password `printf '%s' "$SUPABASE_FUNCTIONS_ADMIN_PASSWORD"`
\set pgbouncer_password `printf '%s' "$PGBOUNCER_PASSWORD"`

ALTER ROLE authenticator WITH PASSWORD :'authenticator_password';
ALTER ROLE supabase_auth_admin WITH PASSWORD :'auth_password';
ALTER ROLE supabase_storage_admin WITH PASSWORD :'storage_password';
ALTER ROLE supabase_functions_admin WITH PASSWORD :'functions_password';
ALTER ROLE pgbouncer WITH PASSWORD :'pgbouncer_password';
