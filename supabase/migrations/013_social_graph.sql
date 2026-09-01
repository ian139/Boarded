-- Social graph: follows, follower/following counts, and the following feed.
-- PostgreSQL/Supabase remains the wire and security boundary. Web and iOS
-- consume the exact same table/RPC contract defined here.

-- ============================================
-- FOLLOWS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.follows (
  follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id),
  CONSTRAINT follows_no_self_follow CHECK (follower_id <> following_id)
);

-- Follower lookups are served by the primary key (follower_id, following_id).
-- This index serves "who follows me" lookups and follower counts.
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON public.follows(following_id);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

-- ============================================
-- FOLLOWS POLICIES
-- ============================================

-- Follow relationships are public among signed-in users; anonymous users have
-- no access to the social graph.
CREATE POLICY "Authenticated users can view follows" ON public.follows
  FOR SELECT TO authenticated
  USING (true);

-- A user can only follow as themselves; the CHECK constraint forbids self-follow.
-- Duplicate follows hit the primary key and surface as a clean 409 conflict.
CREATE POLICY "Users can follow others" ON public.follows
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = follower_id);

-- A user can only remove their own follows.
CREATE POLICY "Users can unfollow" ON public.follows
  FOR DELETE TO authenticated
  USING (auth.uid() = follower_id);

-- ============================================
-- FOLLOWER / FOLLOWING COUNTS
-- ============================================

-- SECURITY INVOKER: the caller's RLS on follows determines what is counted.
-- Authenticated callers see the full social graph, so counts are exact.
CREATE OR REPLACE FUNCTION public.get_profile_follow_counts(target_profile_id uuid)
RETURNS TABLE (follower_count bigint, following_count bigint)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    (SELECT count(*) FROM public.follows WHERE following_id = target_profile_id),
    (SELECT count(*) FROM public.follows WHERE follower_id = target_profile_id);
$$;

-- ============================================
-- FOLLOWING FEED
-- ============================================

-- SECURITY INVOKER: the feed is the caller's own follows joined against routes,
-- so existing routes RLS already restricts results to routes the caller may see
-- (public routes, the caller's own routes, and moderator-visible routes).
-- Private routes of followed users are therefore never leaked.
--
-- Own routes are NOT included: self-follow is forbidden, and the feed is
-- strictly "routes created by users the caller follows".
--
-- Pagination is keyset on (activity_at, route_id) where activity_at is the
-- route's created_at. Routes with a NULL created_at are excluded so every
-- returned activity_at matches the non-null wire type and the cursor tuple
-- comparison stays total. Ordering is newest-first and deterministic because
-- (created_at, id) is a total order. Pass both cursor fields or neither.
CREATE OR REPLACE FUNCTION public.get_following_feed(
  p_cursor_activity_at timestamptz DEFAULT NULL,
  p_cursor_route_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 20
)
RETURNS TABLE (
  route_id uuid,
  activity_at timestamptz,
  author_id uuid,
  author_username text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    r.id AS route_id,
    r.created_at AS activity_at,
    r.user_id AS author_id,
    p.username AS author_username
  FROM public.follows f
  JOIN public.routes r ON r.user_id = f.following_id
  LEFT JOIN public.profiles p ON p.id = f.following_id
  WHERE f.follower_id = auth.uid()
    AND r.created_at IS NOT NULL
    AND (
      p_cursor_activity_at IS NULL
      OR (r.created_at, r.id) < (p_cursor_activity_at, p_cursor_route_id)
    )
  ORDER BY r.created_at DESC NULLS LAST, r.id DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
$$;

-- ============================================
-- GRANTS / REVOKES
-- ============================================

-- Anonymous users get nothing on the social graph. Supabase default
-- privileges may have granted anon/authenticated broad table access, so
-- revoke first and grant only the exact surface below.
REVOKE ALL ON TABLE public.follows FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.get_profile_follow_counts(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_following_feed(timestamptz, uuid, integer) FROM PUBLIC;

GRANT SELECT, INSERT, DELETE ON TABLE public.follows TO authenticated;
GRANT ALL ON TABLE public.follows TO service_role;
GRANT EXECUTE ON FUNCTION public.get_profile_follow_counts(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_following_feed(timestamptz, uuid, integer) TO authenticated;
