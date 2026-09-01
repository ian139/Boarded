import type { FollowingFeedItem, ProfileFollowCounts } from '@boarded/shared/types';
import { createClient } from '../supabase/client.ts';
import type { FeedCursor } from './feed.ts';

export async function getProfileFollowCounts(profileId: string): Promise<ProfileFollowCounts> {
  const { data, error } = await createClient().rpc('get_profile_follow_counts', {
    target_profile_id: profileId,
  });
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) return { follower_count: 0, following_count: 0 };
  return {
    follower_count: Number(row.follower_count),
    following_count: Number(row.following_count),
  };
}

export async function getFollowingFeed(cursor: FeedCursor | null, limit: number): Promise<FollowingFeedItem[]> {
  const { data, error } = await createClient().rpc('get_following_feed', {
    p_cursor_activity_at: cursor?.activityAt ?? null,
    p_cursor_route_id: cursor?.routeId ?? null,
    p_limit: limit,
  });
  if (error) throw error;
  return (data ?? []) as FollowingFeedItem[];
}

export async function isFollowing(profileId: string): Promise<boolean> {
  const supabase = createClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError) throw userError;
  if (!user) return false;

  const { data, error } = await supabase
    .from('follows')
    .select('following_id')
    .eq('follower_id', user.id)
    .eq('following_id', profileId)
    .maybeSingle();
  if (error) throw error;
  return Boolean(data);
}

export async function setFollowing(profileId: string, follow: boolean): Promise<void> {
  const supabase = createClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError) throw userError;
  if (!user) throw new Error('Sign in to follow climbers.');

  const request = follow
    ? supabase.from('follows').insert({ follower_id: user.id, following_id: profileId })
    : supabase.from('follows').delete().eq('follower_id', user.id).eq('following_id', profileId);
  const { error } = await request;
  if (error) throw error;
}
