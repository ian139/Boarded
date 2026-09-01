-- Canonical public social/session domain for Boarded.
-- This migration intentionally replaces the obsolete follow graph with public
-- send posts and meetup/session data shared by every client.

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

-- Public send posts and engagement.
CREATE TABLE public.send_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  attempt_id UUID NOT NULL UNIQUE REFERENCES public.climb_attempts(id) ON DELETE CASCADE,
  caption TEXT,
  image_path TEXT,
  image_alt TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT send_posts_caption_length
    CHECK (caption IS NULL OR char_length(btrim(caption)) BETWEEN 1 AND 2000),
  CONSTRAINT send_posts_image_path_nonempty
    CHECK (image_path IS NULL OR char_length(btrim(image_path)) BETWEEN 1 AND 500),
  CONSTRAINT send_posts_image_alt_length
    CHECK (image_alt IS NULL OR char_length(btrim(image_alt)) BETWEEN 1 AND 300),
  CONSTRAINT send_posts_image_alt_required
    CHECK (image_path IS NULL OR (image_alt IS NOT NULL AND char_length(btrim(image_alt)) BETWEEN 1 AND 300))
);

CREATE TABLE public.send_post_likes (
  post_id UUID NOT NULL REFERENCES public.send_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE public.send_post_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES public.send_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT send_post_comments_content_length
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
CREATE INDEX IF NOT EXISTS idx_send_posts_feed_cursor
  ON public.send_posts(created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_send_posts_user_id
  ON public.send_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_send_post_likes_user_id
  ON public.send_post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_send_post_comments_post_id
  ON public.send_post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_send_post_comments_user_id
  ON public.send_post_comments(user_id);
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
       OR NEW.session_id IS DISTINCT FROM OLD.session_id
       OR NEW.board_route_id IS DISTINCT FROM OLD.board_route_id) THEN
    RAISE EXCEPTION 'attempt ownership and parent keys are immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'send_posts'
     AND (NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.attempt_id IS DISTINCT FROM OLD.attempt_id) THEN
    RAISE EXCEPTION 'post ownership and attempt_id are immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'send_post_likes'
     AND (NEW.post_id IS DISTINCT FROM OLD.post_id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
    RAISE EXCEPTION 'like parent and owner are immutable' USING ERRCODE = '42501';
  ELSIF TG_TABLE_NAME = 'send_post_comments'
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

CREATE OR REPLACE FUNCTION public.ensure_send_post_attempt_is_sent()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  attempt_owner UUID;
  attempt_outcome TEXT;
BEGIN
  SELECT ca.user_id, ca.outcome
    INTO attempt_owner, attempt_outcome
    FROM public.climb_attempts AS ca
   WHERE ca.id = NEW.attempt_id;
  IF attempt_owner IS DISTINCT FROM NEW.user_id OR attempt_outcome IS DISTINCT FROM 'sent' THEN
    RAISE EXCEPTION 'send post requires a sent attempt owned by its author'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_climbing_session_parent_change ON public.climbing_sessions;
CREATE TRIGGER prevent_climbing_session_parent_change
  BEFORE UPDATE ON public.climbing_sessions
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();
DROP TRIGGER IF EXISTS prevent_climb_attempt_parent_change ON public.climb_attempts;
CREATE TRIGGER prevent_climb_attempt_parent_change
  BEFORE UPDATE ON public.climb_attempts
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();
DROP TRIGGER IF EXISTS prevent_send_post_parent_change ON public.send_posts;
CREATE TRIGGER prevent_send_post_parent_change
  BEFORE UPDATE ON public.send_posts
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();
DROP TRIGGER IF EXISTS ensure_send_post_attempt_is_sent ON public.send_posts;
CREATE TRIGGER ensure_send_post_attempt_is_sent
  BEFORE INSERT OR UPDATE ON public.send_posts
  FOR EACH ROW EXECUTE FUNCTION public.ensure_send_post_attempt_is_sent();
DROP TRIGGER IF EXISTS prevent_send_post_like_parent_change ON public.send_post_likes;
CREATE TRIGGER prevent_send_post_like_parent_change
  BEFORE UPDATE ON public.send_post_likes
  FOR EACH ROW EXECUTE FUNCTION public.prevent_social_parent_change();
DROP TRIGGER IF EXISTS prevent_send_post_comment_parent_change ON public.send_post_comments;
CREATE TRIGGER prevent_send_post_comment_parent_change
  BEFORE UPDATE ON public.send_post_comments
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
DROP TRIGGER IF EXISTS update_send_posts_updated_at ON public.send_posts;
CREATE TRIGGER update_send_posts_updated_at
  BEFORE UPDATE ON public.send_posts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
DROP TRIGGER IF EXISTS update_send_post_comments_updated_at ON public.send_post_comments;
CREATE TRIGGER update_send_post_comments_updated_at
  BEFORE UPDATE ON public.send_post_comments
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
ALTER TABLE public.send_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.send_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.send_post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetup_attendees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetup_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Send posts are publicly readable" ON public.send_posts
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users can create their own send posts" ON public.send_posts
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors can update their own send posts" ON public.send_posts
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors and moderators can delete send posts" ON public.send_posts
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id OR public.is_moderator());
CREATE POLICY "Post likes are publicly readable" ON public.send_post_likes
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users can create their own post likes" ON public.send_post_likes
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own post likes" ON public.send_post_likes
  FOR DELETE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Post comments are publicly readable" ON public.send_post_comments
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users can create their own post comments" ON public.send_post_comments
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors can update their own post comments" ON public.send_post_comments
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authors and moderators can delete post comments" ON public.send_post_comments
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
  public.send_posts, public.send_post_likes, public.send_post_comments,
  public.meetups, public.meetup_attendees, public.meetup_comments
  FROM anon, authenticated;
GRANT SELECT ON TABLE public.send_posts, public.send_post_likes,
  public.send_post_comments, public.meetups, public.meetup_attendees,
  public.meetup_comments TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.climbing_sessions,
  public.climb_attempts, public.send_posts, public.send_post_likes,
  public.send_post_comments, public.meetups, public.meetup_attendees,
  public.meetup_comments TO authenticated;
-- Joining is the only attendee insertion path; PostgREST has no direct INSERT.
REVOKE INSERT, UPDATE ON TABLE public.meetup_attendees FROM authenticated;
GRANT ALL ON TABLE public.climbing_sessions, public.climb_attempts,
  public.send_posts, public.send_post_likes, public.send_post_comments,
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

-- Public feed RPC: only already-published attempts are joined and only safe
-- public attempt/profile fields are selected.  This bypasses owner-only RLS
-- intentionally, but never selects sessions or private attempt notes.
CREATE OR REPLACE FUNCTION public.get_send_feed(
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
    'attempt_id', sp.attempt_id,
    'caption', sp.caption,
    'image_path', sp.image_path,
    'image_alt', sp.image_alt,
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
    'attempt', jsonb_build_object(
      'id', ca.id,
      'board_route_id', ca.board_route_id,
      'route_name', ca.route_name,
      'discipline', ca.discipline,
      'grade_system', ca.grade_system,
      'grade_label', ca.grade_label,
      'outcome', ca.outcome,
      'attempt_number', ca.attempt_number,
      'occurred_at', ca.occurred_at,
      'created_at', ca.created_at
    ),
    'like_count', (SELECT count(*) FROM public.send_post_likes AS spl WHERE spl.post_id = sp.id),
    'comment_count', (SELECT count(*) FROM public.send_post_comments AS spc WHERE spc.post_id = sp.id),
    'is_liked', EXISTS (
      SELECT 1 FROM public.send_post_likes AS spl
      WHERE spl.post_id = sp.id AND spl.user_id = auth.uid()
    )
  )
  FROM public.send_posts AS sp
  JOIN public.climb_attempts AS ca ON ca.id = sp.attempt_id
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
REVOKE ALL ON FUNCTION public.get_send_feed(timestamptz, uuid, uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_send_feed(timestamptz, uuid, uuid, integer) TO anon, authenticated;

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
