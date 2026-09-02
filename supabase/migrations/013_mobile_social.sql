-- Canonical public social/session domain for Boarded.
-- This migration establishes the canonical session-post domain, private sessions
-- and attempts, and public meetups shared by every client.

-- Profiles are public for this release so nested social authors are never
-- hidden by profile RLS.  Precise home coordinates are deliberately not stored.
UPDATE public.profiles SET is_public = true WHERE is_public IS DISTINCT FROM true;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_public;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_area TEXT;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.profiles'::regclass
      AND conname = 'profiles_home_area_length'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_home_area_length
      CHECK (home_area IS NULL OR char_length(btrim(home_area)) BETWEEN 1 AND 120);
  END IF;
END
$$;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Sessions and private attempts.
CREATE TABLE public.climbing_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  venue_name TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT climbing_sessions_venue_name_length
    CHECK (char_length(btrim(venue_name)) BETWEEN 1 AND 120),
  CONSTRAINT climbing_sessions_ended_after_started
    CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE TABLE public.climb_attempts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES public.climbing_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  board_route_id UUID REFERENCES public.routes(id) ON DELETE SET NULL,
  route_name TEXT NOT NULL,
  discipline TEXT NOT NULL,
  grade_system TEXT NOT NULL,
  grade_label TEXT NOT NULL,
  outcome TEXT NOT NULL,
  attempt_number INTEGER NOT NULL,
  notes TEXT,
  occurred_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT climb_attempts_route_name_length
    CHECK (char_length(btrim(route_name)) BETWEEN 1 AND 120),
  CONSTRAINT climb_attempts_grade_label_length
    CHECK (char_length(btrim(grade_label)) BETWEEN 1 AND 24),
  CONSTRAINT climb_attempts_notes_length
    CHECK (notes IS NULL OR char_length(btrim(notes)) BETWEEN 1 AND 1000),
  CONSTRAINT climb_attempts_discipline_check
    CHECK (discipline IN ('boulder', 'sport', 'trad', 'top_rope', 'board', 'other')),
  CONSTRAINT climb_attempts_grade_system_check
    CHECK (grade_system IN ('v_scale', 'font', 'yds', 'custom')),
  CONSTRAINT climb_attempts_outcome_check
    CHECK (outcome IN ('sent', 'fell', 'stopped')),
  CONSTRAINT climb_attempts_attempt_number_positive
    CHECK (attempt_number > 0)
);

-- Public session posts and engagement.
CREATE TABLE public.session_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  session_id UUID NOT NULL UNIQUE REFERENCES public.climbing_sessions(id) ON DELETE CASCADE,
  featured_attempt_id UUID NOT NULL REFERENCES public.climb_attempts(id) ON DELETE CASCADE,
  caption TEXT,
  image_path TEXT NOT NULL,
  image_alt TEXT NOT NULL,
  overlay_style TEXT NOT NULL DEFAULT 'stats',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT session_posts_caption_length
    CHECK (caption IS NULL OR char_length(btrim(caption)) BETWEEN 1 AND 2000),
  CONSTRAINT session_posts_image_path_length
    CHECK (char_length(btrim(image_path)) BETWEEN 1 AND 500),
  CONSTRAINT session_posts_image_path_canonical
    CHECK (
      image_path = lower(user_id::text) || '/' || lower(id::text) || '.jpg'
      OR image_path = user_id::text || '/' || id::text || '.jpg'
    ),
  CONSTRAINT session_posts_image_alt_length
    CHECK (char_length(btrim(image_alt)) BETWEEN 1 AND 300),
  CONSTRAINT session_posts_overlay_style_check
    CHECK (overlay_style IN ('stats', 'attempt_timeline'))
);

CREATE TABLE public.session_post_likes (
  post_id UUID NOT NULL REFERENCES public.session_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE public.session_post_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES public.session_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT session_post_comments_content_length
    CHECK (char_length(btrim(content)) BETWEEN 1 AND 2000)
);

-- Meetups and their public engagement.
CREATE TABLE public.meetups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  venue_name TEXT NOT NULL,
  area TEXT NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ,
  capacity INTEGER,
  status TEXT NOT NULL DEFAULT 'scheduled',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT meetups_title_length
    CHECK (char_length(btrim(title)) BETWEEN 1 AND 120),
  CONSTRAINT meetups_description_length
    CHECK (char_length(btrim(description)) BETWEEN 1 AND 3000),
  CONSTRAINT meetups_venue_name_length
    CHECK (char_length(btrim(venue_name)) BETWEEN 1 AND 160),
  CONSTRAINT meetups_area_length
    CHECK (char_length(btrim(area)) BETWEEN 1 AND 120),
  CONSTRAINT meetups_status_check
    CHECK (status IN ('scheduled', 'cancelled')),
  CONSTRAINT meetups_capacity_check
    CHECK (capacity IS NULL OR capacity BETWEEN 2 AND 500),
  CONSTRAINT meetups_ends_after_starts
    CHECK (ends_at IS NULL OR ends_at >= starts_at)
);

CREATE TABLE public.meetup_attendees (
  meetup_id UUID NOT NULL REFERENCES public.meetups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (meetup_id, user_id)
);

CREATE TABLE public.meetup_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meetup_id UUID NOT NULL REFERENCES public.meetups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT meetup_comments_content_length
    CHECK (char_length(btrim(content)) BETWEEN 1 AND 2000)
);

-- Lookup indexes support public feed pagination and nested authors/parents.
CREATE INDEX IF NOT EXISTS idx_climbing_sessions_user_id
  ON public.climbing_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_climb_attempts_session_id
  ON public.climb_attempts(session_id);
CREATE INDEX IF NOT EXISTS idx_climb_attempts_user_id
  ON public.climb_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_climb_attempts_board_route_id
  ON public.climb_attempts(board_route_id);
CREATE INDEX IF NOT EXISTS idx_session_posts_feed_cursor
  ON public.session_posts(created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_session_posts_user_id
  ON public.session_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_session_posts_session_id
  ON public.session_posts(session_id);
CREATE INDEX IF NOT EXISTS idx_session_posts_featured_attempt_id
  ON public.session_posts(featured_attempt_id);
CREATE INDEX IF NOT EXISTS idx_session_post_likes_user_id
  ON public.session_post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_session_post_comments_post_id
  ON public.session_post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_session_post_comments_user_id
  ON public.session_post_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_meetups_upcoming
  ON public.meetups(status, starts_at, id);
CREATE INDEX IF NOT EXISTS idx_meetups_organizer_id
  ON public.meetups(organizer_id);
CREATE INDEX IF NOT EXISTS idx_meetup_attendees_user_id
  ON public.meetup_attendees(user_id);
CREATE INDEX IF NOT EXISTS idx_meetup_comments_meetup_id
  ON public.meetup_comments(meetup_id);
CREATE INDEX IF NOT EXISTS idx_meetup_comments_user_id
  ON public.meetup_comments(user_id);

-- Keep relationship keys immutable through PostgREST updates.  RLS WITH CHECK
-- covers the current owner while this trigger covers the old/new row boundary.
CREATE OR REPLACE FUNCTION public.prevent_social_parent_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_TABLE_NAME = 'climbing_sessions'
     AND NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    RAISE EXCEPTION 'session user_id is immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'climb_attempts'
     AND (NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.session_id IS DISTINCT FROM OLD.session_id) THEN
    RAISE EXCEPTION 'attempt ownership and parent keys are immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'climb_attempts'
     AND NEW.board_route_id IS DISTINCT FROM OLD.board_route_id
     AND NOT (
       OLD.board_route_id IS NOT NULL
       AND NEW.board_route_id IS NULL
       AND NOT EXISTS (
         SELECT 1 FROM public.routes AS r WHERE r.id = OLD.board_route_id
       )
     ) THEN
    RAISE EXCEPTION 'attempt board_route_id is immutable while the route exists' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'session_posts'
     AND (NEW.id IS DISTINCT FROM OLD.id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.session_id IS DISTINCT FROM OLD.session_id
       OR NEW.featured_attempt_id IS DISTINCT FROM OLD.featured_attempt_id) THEN
    RAISE EXCEPTION 'post identity, cursor fields, ownership, session_id, and featured_attempt_id are immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'session_post_likes'
     AND (NEW.post_id IS DISTINCT FROM OLD.post_id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
    RAISE EXCEPTION 'like parent and owner are immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'session_post_comments'
     AND (NEW.post_id IS DISTINCT FROM OLD.post_id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
    RAISE EXCEPTION 'comment parent and owner are immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'meetups'
     AND NEW.organizer_id IS DISTINCT FROM OLD.organizer_id THEN
    RAISE EXCEPTION 'meetup organizer_id is immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'meetup_attendees'
     AND (NEW.meetup_id IS DISTINCT FROM OLD.meetup_id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
    RAISE EXCEPTION 'attendance parent and owner are immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'meetup_comments'
     AND (NEW.meetup_id IS DISTINCT FROM OLD.meetup_id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
    RAISE EXCEPTION 'meetup comment parent and owner are immutable' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

-- Ensure session post belongs to an ended session and valid featured attempt owned by author.
CREATE OR REPLACE FUNCTION public.ensure_session_post_validity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  sess_owner UUID;
  sess_ended TIMESTAMPTZ;
  att_owner UUID;
  att_session UUID;
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.created_at := now();
  END IF;

  SELECT cs.user_id, cs.ended_at
    INTO sess_owner, sess_ended
    FROM public.climbing_sessions AS cs
   WHERE cs.id = NEW.session_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session post requires an existing climbing session'
      USING ERRCODE = '23514';
  END IF;

  IF sess_owner IS DISTINCT FROM NEW.user_id OR sess_ended IS NULL THEN
    RAISE EXCEPTION 'session post requires an ended session owned by its author'
      USING ERRCODE = '23514';
  END IF;

  SELECT ca.user_id, ca.session_id
    INTO att_owner, att_session
    FROM public.climb_attempts AS ca
   WHERE ca.id = NEW.featured_attempt_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session post requires an existing featured attempt'
      USING ERRCODE = '23514';
  END IF;

  IF att_owner IS DISTINCT FROM NEW.user_id OR att_session IS DISTINCT FROM NEW.session_id THEN
    RAISE EXCEPTION 'featured attempt must belong to the posted session and author'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

-- Prevent reopening a session once it has been published as a session post.
CREATE OR REPLACE FUNCTION public.prevent_published_session_reopen()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF OLD.ended_at IS NOT NULL AND NEW.ended_at IS NULL
     AND EXISTS (
       SELECT 1
         FROM public.session_posts AS sp
        WHERE sp.session_id = NEW.id
     ) THEN
    RAISE EXCEPTION 'published sessions cannot be reopened'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_published_session_reopen ON public.climbing_sessions;
CREATE TRIGGER prevent_published_session_reopen
  BEFORE UPDATE OF ended_at ON public.climbing_sessions
  FOR EACH ROW EXECUTE FUNCTION public.prevent_published_session_reopen();

DROP TRIGGER IF EXISTS prevent_climbing_session_parent_change ON public.climbing_sessions;
CREATE TRIGGER prevent_climbing_session_parent_change
  BEFORE UPDATE ON public.climbing_sessions
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();

DROP TRIGGER IF EXISTS prevent_climb_attempt_parent_change ON public.climb_attempts;
CREATE TRIGGER prevent_climb_attempt_parent_change
  BEFORE UPDATE ON public.climb_attempts
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();

DROP TRIGGER IF EXISTS prevent_session_post_parent_change ON public.session_posts;
CREATE TRIGGER prevent_session_post_parent_change
  BEFORE UPDATE ON public.session_posts
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();

DROP TRIGGER IF EXISTS ensure_session_post_validity ON public.session_posts;
CREATE TRIGGER ensure_session_post_validity
  BEFORE INSERT OR UPDATE ON public.session_posts
  FOR EACH ROW EXECUTE FUNCTION public.ensure_session_post_validity();

DROP TRIGGER IF EXISTS prevent_session_post_like_parent_change ON public.session_post_likes;
CREATE TRIGGER prevent_session_post_like_parent_change
  BEFORE UPDATE ON public.session_post_likes
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();

DROP TRIGGER IF EXISTS prevent_session_post_comment_parent_change ON public.session_post_comments;
CREATE TRIGGER prevent_session_post_comment_parent_change
  BEFORE UPDATE ON public.session_post_comments
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();

DROP TRIGGER IF EXISTS prevent_meetup_parent_change ON public.meetups;
CREATE TRIGGER prevent_meetup_parent_change
  BEFORE UPDATE ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();

DROP TRIGGER IF EXISTS prevent_meetup_attendance_parent_change ON public.meetup_attendees;
CREATE TRIGGER prevent_meetup_attendance_parent_change
  BEFORE UPDATE ON public.meetup_attendees
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();

DROP TRIGGER IF EXISTS prevent_meetup_comment_parent_change ON public.meetup_comments;
CREATE TRIGGER prevent_meetup_comment_parent_change
  BEFORE UPDATE ON public.meetup_comments
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();

DROP TRIGGER IF EXISTS update_climbing_sessions_updated_at ON public.climbing_sessions;
CREATE TRIGGER update_climbing_sessions_updated_at
  BEFORE UPDATE ON public.climbing_sessions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_session_posts_updated_at ON public.session_posts;
CREATE TRIGGER update_session_posts_updated_at
  BEFORE UPDATE ON public.session_posts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_session_post_comments_updated_at ON public.session_post_comments;
CREATE TRIGGER update_session_post_comments_updated_at
  BEFORE UPDATE ON public.session_post_comments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_meetups_updated_at ON public.meetups;
CREATE TRIGGER update_meetups_updated_at
  BEFORE UPDATE ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_meetup_comments_updated_at ON public.meetup_comments;
CREATE TRIGGER update_meetup_comments_updated_at
  BEFORE UPDATE ON public.meetup_comments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Private session/attempt policies.
ALTER TABLE public.climbing_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.climb_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners and moderators can read climbing sessions" ON public.climbing_sessions
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR public.is_moderator());
CREATE POLICY "Users can create their own climbing sessions" ON public.climbing_sessions
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own climbing sessions" ON public.climbing_sessions
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Owners and moderators can delete climbing sessions" ON public.climbing_sessions
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id OR public.is_moderator());

CREATE POLICY "Owners and moderators can read climb attempts" ON public.climb_attempts
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR public.is_moderator());
CREATE POLICY "Users can create attempts in their own sessions" ON public.climb_attempts
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.climbing_sessions AS cs
      WHERE cs.id = session_id AND cs.user_id = auth.uid()
    )
  );
CREATE POLICY "Users can update their own climb attempts" ON public.climb_attempts
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.climbing_sessions AS cs
      WHERE cs.id = session_id AND cs.user_id = auth.uid()
    )
  );
CREATE POLICY "Owners and moderators can delete climb attempts" ON public.climb_attempts
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id OR public.is_moderator());

-- Public post and meetup reads, with owner-scoped writes.
ALTER TABLE public.session_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetup_attendees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetup_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Session posts are publicly readable" ON public.session_posts
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users can create their own session posts" ON public.session_posts
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors can update their own session posts" ON public.session_posts
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors and moderators can delete session posts" ON public.session_posts
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id OR public.is_moderator());

CREATE POLICY "Session post likes are publicly readable" ON public.session_post_likes
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users can create their own session post likes" ON public.session_post_likes
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own session post likes" ON public.session_post_likes
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Session post comments are publicly readable" ON public.session_post_comments
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users can create their own session post comments" ON public.session_post_comments
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors can update their own session post comments" ON public.session_post_comments
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors and moderators can delete session post comments" ON public.session_post_comments
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id OR public.is_moderator());

CREATE POLICY "Meetups are publicly readable" ON public.meetups
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users can create their own meetups" ON public.meetups
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = organizer_id);
CREATE POLICY "Organizers can update their own meetups" ON public.meetups
  FOR UPDATE TO authenticated
  USING (auth.uid() = organizer_id) WITH CHECK (auth.uid() = organizer_id);
CREATE POLICY "Organizers and moderators can delete meetups" ON public.meetups
  FOR DELETE TO authenticated
  USING (auth.uid() = organizer_id OR public.is_moderator());

CREATE POLICY "Meetup attendees are publicly readable" ON public.meetup_attendees
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users can leave meetups" ON public.meetup_attendees
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Meetup comments are publicly readable" ON public.meetup_comments
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users can create their own meetup comments" ON public.meetup_comments
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors can update their own meetup comments" ON public.meetup_comments
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors and moderators can delete meetup comments" ON public.meetup_comments
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id OR public.is_moderator());

-- Expose exactly the API surface governed above.
GRANT USAGE ON SCHEMA public TO anon, authenticated;
REVOKE ALL ON TABLE public.climbing_sessions, public.climb_attempts,
  public.session_posts, public.session_post_likes, public.session_post_comments,
  public.meetups, public.meetup_attendees, public.meetup_comments
  FROM anon, authenticated;
GRANT SELECT ON TABLE public.session_posts, public.session_post_likes,
  public.session_post_comments, public.meetups, public.meetup_attendees,
  public.meetup_comments TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.climbing_sessions,
  public.climb_attempts, public.session_posts, public.session_post_likes,
  public.session_post_comments, public.meetups, public.meetup_attendees,
  public.meetup_comments TO authenticated;
-- Joining is the only attendee insertion path; PostgREST has no direct INSERT.
REVOKE INSERT, UPDATE ON TABLE public.meetup_attendees FROM authenticated;
GRANT ALL ON TABLE public.climbing_sessions, public.climb_attempts,
  public.session_posts, public.session_post_likes, public.session_post_comments,
  public.meetups, public.meetup_attendees, public.meetup_comments TO service_role;

-- Race-safe join path.  The organizer counts as one capacity slot while
-- attendee rows contain joiners only.
CREATE OR REPLACE FUNCTION public.join_meetup(meetup_id UUID)
RETURNS public.meetup_attendees
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  caller_id UUID := auth.uid();
  target_id UUID := meetup_id;
  meetup_row public.meetups%ROWTYPE;
  existing_attendance public.meetup_attendees;
  attendee_count INTEGER;
BEGIN
  IF caller_id IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  SELECT m.* INTO meetup_row
    FROM public.meetups AS m
   WHERE m.id = target_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'meetup not found' USING ERRCODE = 'P0002';
  END IF;
  SELECT ma.* INTO existing_attendance
    FROM public.meetup_attendees AS ma
   WHERE ma.meetup_id = target_id AND ma.user_id = caller_id;
  IF FOUND THEN
    RETURN existing_attendance;
  END IF;
  IF meetup_row.organizer_id = caller_id THEN
    RAISE EXCEPTION 'organizers cannot join their own meetup' USING ERRCODE = '42501';
  END IF;
  IF meetup_row.status <> 'scheduled' THEN
    RAISE EXCEPTION 'cancelled meetups cannot be joined' USING ERRCODE = 'P0001';
  END IF;
  IF COALESCE(meetup_row.ends_at, meetup_row.starts_at) <= now() THEN
    RAISE EXCEPTION 'past meetups cannot be joined' USING ERRCODE = 'P0001';
  END IF;
  SELECT count(*)::INTEGER INTO attendee_count
    FROM public.meetup_attendees AS ma
   WHERE ma.meetup_id = target_id;
  IF meetup_row.capacity IS NOT NULL AND 1 + attendee_count >= meetup_row.capacity THEN
    RAISE EXCEPTION 'meetup is full' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.meetup_attendees (meetup_id, user_id)
  VALUES (target_id, caller_id)
  RETURNING * INTO existing_attendance;
  RETURN existing_attendance;
END;
$$;
REVOKE ALL ON FUNCTION public.join_meetup(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_meetup(uuid) TO authenticated;

-- Public session feed RPC: selects safe post fields, nested author, and session
-- projection with attempt count, send count, and safe featured attempt fields.
-- This bypasses owner-only RLS intentionally, but never selects raw sessions,
-- notes, or unrelated private attempts.
CREATE OR REPLACE FUNCTION public.get_session_feed(
  before_created_at TIMESTAMPTZ DEFAULT NULL,
  before_id UUID DEFAULT NULL,
  author_filter UUID DEFAULT NULL,
  page_size INTEGER DEFAULT 20
)
RETURNS SETOF JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'id', sp.id,
    'user_id', sp.user_id,
    'session_id', sp.session_id,
    'featured_attempt_id', sp.featured_attempt_id,
    'caption', sp.caption,
    'image_path', sp.image_path,
    'image_alt', sp.image_alt,
    'overlay_style', sp.overlay_style,
    'created_at', sp.created_at,
    'updated_at', sp.updated_at,
    'author', jsonb_build_object(
      'id', p.id,
      'username', p.username,
      'full_name', p.full_name,
      'avatar_url', p.avatar_url,
      'bio', p.bio,
      'home_area', p.home_area
    ),
    'session', jsonb_build_object(
      'id', cs.id,
      'venue_name', cs.venue_name,
      'started_at', cs.started_at,
      'ended_at', cs.ended_at,
      'duration_seconds', ROUND(EXTRACT(EPOCH FROM (cs.ended_at - cs.started_at)))::INTEGER,
      'attempt_count', (SELECT count(*)::INTEGER FROM public.climb_attempts AS ca_all WHERE ca_all.session_id = cs.id),
      'send_count', (SELECT count(*)::INTEGER FROM public.climb_attempts AS ca_sends WHERE ca_sends.session_id = cs.id AND ca_sends.outcome = 'sent'),
      'featured_attempt', jsonb_build_object(
        'id', ca.id,
        'route_name', ca.route_name,
        'discipline', ca.discipline,
        'grade_system', ca.grade_system,
        'grade_label', ca.grade_label,
        'outcome', ca.outcome,
        'attempt_number', ca.attempt_number,
        'occurred_at', ca.occurred_at
      ),
      'attempt_timeline', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'attempt_number', ca_timeline.attempt_number,
            'outcome', ca_timeline.outcome
          )
          ORDER BY ca_timeline.attempt_number
        )
        FROM public.climb_attempts AS ca_timeline
        WHERE ca_timeline.session_id = cs.id
      )
    ),
    'like_count', (SELECT count(*)::INTEGER FROM public.session_post_likes AS spl WHERE spl.post_id = sp.id),
    'comment_count', (SELECT count(*)::INTEGER FROM public.session_post_comments AS spc WHERE spc.post_id = sp.id),
    'is_liked', EXISTS (
      SELECT 1 FROM public.session_post_likes AS spl
      WHERE spl.post_id = sp.id AND spl.user_id = auth.uid()
    )
  )
  FROM public.session_posts AS sp
  JOIN public.climbing_sessions AS cs ON cs.id = sp.session_id
  JOIN public.climb_attempts AS ca ON ca.id = sp.featured_attempt_id
  JOIN public.profiles AS p ON p.id = sp.user_id
  WHERE (author_filter IS NULL OR sp.user_id = author_filter)
    AND (
      (before_created_at IS NULL AND before_id IS NULL)
      OR (
        before_created_at IS NOT NULL
        AND before_id IS NOT NULL
        AND (sp.created_at, sp.id) < (before_created_at, before_id)
      )
    )
  ORDER BY sp.created_at DESC, sp.id DESC
  LIMIT LEAST(GREATEST(COALESCE(page_size, 20), 1), 50);
$$;
REVOKE ALL ON FUNCTION public.get_session_feed(timestamptz, uuid, uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_session_feed(timestamptz, uuid, uuid, integer) TO anon, authenticated;

-- Public social-media uploads use <auth.uid>/<post-id>.jpg as the first path
-- component.  Public reads are safe because the post path is not an access
-- secret; writes remain owner-prefixed and authenticated.
INSERT INTO storage.buckets (id, name, public)
VALUES ('social-media', 'social-media', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;
DROP POLICY IF EXISTS "Public read access for social media" ON storage.objects;
DROP POLICY IF EXISTS "Owner-prefixed social media insert" ON storage.objects;
DROP POLICY IF EXISTS "Owner-prefixed social media update" ON storage.objects;
DROP POLICY IF EXISTS "Owner-prefixed social media delete" ON storage.objects;
CREATE POLICY "Public read access for social media" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'social-media');
CREATE POLICY "Owner-prefixed social media insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'social-media'
    AND (storage.foldername(name))[1] = (select auth.uid()::text)
  );
CREATE POLICY "Owner-prefixed social media update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'social-media'
    AND (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'social-media'
    AND (storage.foldername(name))[1] = (select auth.uid()::text)
  );
CREATE POLICY "Owner-prefixed social media delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'social-media'
    AND (storage.foldername(name))[1] = (select auth.uid()::text)
  );
