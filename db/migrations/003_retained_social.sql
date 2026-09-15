-- Preservation destination for the nine non-web tables introduced by historical
-- migration 013. This is an EMPTY additive archive, never an automatic import or
-- a declaration that an existing deployment's data has already been preserved.
-- Do not apply the old platform migration or copy its grants/RPCs/auth functions.
-- The runtime role cannot read or mutate this schema; there are no web APIs.
--
-- Before cutover, preserve an encrypted, restorable source dump and all referenced
-- social-media bytes, and inventory every source table, row count, key and checksum.
-- With a trusted offline tool, stage explicit column lists, review identity mappings,
-- import in parent-first order, then reconcile row counts, relationships, timestamps,
-- private attempt notes and immutable timeline JSON against that inventory.
-- Never infer identity from a display name, email alone or a browser-owned claim.
-- Preserve original identity/profile records alongside the source backup. UUID owner
-- references below intentionally do not FK to active profiles/users/routes: deletion
-- of an active account or route MUST NOT erase or rewrite historical archive data.
-- Keep original image_path values and archived bytes; do not rewrite them into a
-- public serving path or expose private sessions while importing public posts.
--
-- Active-table import likewise requires explicit reviewed mappings and nullable
-- historical owner preservation. Profiles.home_area belongs to the active schema.
-- Do not blindly copy old sessions, password hashes, roles, tokens, URLs or ACLs:
-- invalidate old sessions; transfer credentials only through a verified supported
-- conversion, otherwise use ownership-verified account recovery. Conflicting IDs,
-- missing referenced identities or invalid rows must stop/quarantine the import,
-- never silently drop or assign them to the operator. Source originals stay intact.
-- If these retained records are reactivated later, first restore their domain
-- invariants and authorization in a separate reviewed migration. Current archival
-- constraints preserve shape without recreating exposed SECURITY DEFINER RPCs.
CREATE SCHEMA retained_013 AUTHORIZATION boarded_migrator;
REVOKE ALL ON SCHEMA retained_013 FROM PUBLIC, boarded_app;
ALTER DEFAULT PRIVILEGES FOR ROLE boarded_migrator IN SCHEMA retained_013
  REVOKE ALL ON TABLES FROM PUBLIC, boarded_app;
ALTER DEFAULT PRIVILEGES FOR ROLE boarded_migrator IN SCHEMA retained_013
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, boarded_app;

CREATE TABLE retained_013.climbing_sessions (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  user_id UUID NOT NULL,
  venue_name TEXT NOT NULL CHECK (char_length(btrim(venue_name)) BETWEEN 1 AND 120),
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ CHECK (ended_at IS NULL OR ended_at >= started_at),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE retained_013.climb_attempts (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES retained_013.climbing_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  board_route_id UUID,
  route_name TEXT NOT NULL CHECK (char_length(btrim(route_name)) BETWEEN 1 AND 120),
  discipline TEXT NOT NULL CHECK (discipline IN ('boulder', 'sport', 'trad', 'top_rope', 'board', 'other')),
  grade_system TEXT NOT NULL CHECK (grade_system IN ('v_scale', 'font', 'yds', 'custom')),
  grade_label TEXT NOT NULL CHECK (char_length(btrim(grade_label)) BETWEEN 1 AND 24),
  outcome TEXT NOT NULL CHECK (outcome IN ('sent', 'fell', 'stopped')),
  attempt_number INTEGER NOT NULL CHECK (attempt_number > 0),
  notes TEXT CHECK (notes IS NULL OR char_length(btrim(notes)) BETWEEN 1 AND 1000),
  occurred_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE retained_013.session_posts (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  user_id UUID NOT NULL,
  session_id UUID NOT NULL UNIQUE REFERENCES retained_013.climbing_sessions(id) ON DELETE CASCADE,
  featured_attempt_id UUID NOT NULL REFERENCES retained_013.climb_attempts(id) ON DELETE CASCADE,
  caption TEXT CHECK (caption IS NULL OR char_length(btrim(caption)) BETWEEN 1 AND 2000),
  image_path TEXT NOT NULL CHECK (
    char_length(btrim(image_path)) BETWEEN 1 AND 500
    AND image_path = user_id::text || '/' || id::text || '.jpg'
  ),
  image_alt TEXT NOT NULL CHECK (char_length(btrim(image_alt)) BETWEEN 1 AND 300),
  overlay_style TEXT NOT NULL DEFAULT 'stats' CHECK (overlay_style IN ('stats', 'attempt_timeline')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE retained_013.session_post_attempt_timeline_snapshots (
  post_id UUID PRIMARY KEY REFERENCES retained_013.session_posts(id) ON DELETE CASCADE,
  timeline JSONB NOT NULL DEFAULT '[]'::jsonb
);
CREATE TABLE retained_013.session_post_likes (
  post_id UUID NOT NULL REFERENCES retained_013.session_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, user_id)
);
CREATE TABLE retained_013.session_post_comments (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES retained_013.session_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  content TEXT NOT NULL CHECK (char_length(btrim(content)) BETWEEN 1 AND 2000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE retained_013.meetups (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  organizer_id UUID NOT NULL,
  title TEXT NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 120),
  description TEXT NOT NULL CHECK (char_length(btrim(description)) BETWEEN 1 AND 3000),
  venue_name TEXT NOT NULL CHECK (char_length(btrim(venue_name)) BETWEEN 1 AND 160),
  area TEXT NOT NULL CHECK (char_length(btrim(area)) BETWEEN 1 AND 120),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ CHECK (ends_at IS NULL OR ends_at >= starts_at),
  capacity INTEGER CHECK (capacity IS NULL OR capacity BETWEEN 2 AND 500),
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE retained_013.meetup_attendees (
  meetup_id UUID NOT NULL REFERENCES retained_013.meetups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (meetup_id, user_id)
);
CREATE TABLE retained_013.meetup_comments (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  meetup_id UUID NOT NULL REFERENCES retained_013.meetups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  content TEXT NOT NULL CHECK (char_length(btrim(content)) BETWEEN 1 AND 2000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
REVOKE ALL ON ALL TABLES IN SCHEMA retained_013 FROM PUBLIC, boarded_app;
