import type { FollowingFeedItem, Route, Wall } from '@boarded/shared/types';

export interface FeedCursor {
  activityAt: string;
  routeId: string;
}

export interface FeedPage {
  items: FollowingFeedItem[];
  cursor: FeedCursor | null;
  hasMore: boolean;
}
export interface EnrichedFeedItem extends FollowingFeedItem {
  route?: Route;
  wall?: Wall;
}

export function enrichFeedItems(
  items: FollowingFeedItem[],
  routes: Route[],
  walls: Wall[],
): EnrichedFeedItem[] {
  const routeById = Object.fromEntries(routes.map((route) => [route.id, route]));
  const wallById = Object.fromEntries(walls.map((wall) => [wall.id, wall]));
  return items.map((item) => {
    const route = routeById[item.route_id];
    return {
      ...item,
      route,
      wall: route ? wallById[route.wall_id] : undefined,
    };
  });
}

export function mergeFeedPage(
  current: FollowingFeedItem[],
  incoming: FollowingFeedItem[],
  pageSize: number,
): FeedPage {
  const seen = new Set(current.map((item) => item.route_id));
  const items = [...current];
  for (const item of incoming) {
    if (!seen.has(item.route_id)) {
      seen.add(item.route_id);
      items.push(item);
    }
  }

  const last = incoming.at(-1);
  return {
    items,
    cursor: last ? { activityAt: last.activity_at, routeId: last.route_id } : null,
    hasMore: incoming.length === pageSize,
  };
}
