import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import type { FollowingFeedItem, Route, Wall } from '@boarded/shared/types';
import { enrichFeedItems, mergeFeedPage } from '../social/feed';

const item = (route_id: string, activity_at: string): FollowingFeedItem => ({
  route_id,
  activity_at,
  author_id: `author-${route_id}`,
  author_username: 'climber',
});

describe('following feed pagination', () => {
  it('uses the final RPC row as the stable timestamp and UUID cursor', () => {
    const page = mergeFeedPage([], [
      item('b-route', '2026-08-31T12:00:00.000Z'),
      item('a-route', '2026-08-31T12:00:00.000Z'),
    ], 2);

    assert.deepEqual(page.cursor, {
      activityAt: '2026-08-31T12:00:00.000Z',
      routeId: 'a-route',
    });
    assert.equal(page.hasMore, true);
  });

  it('deduplicates a repeated boundary row while preserving server order', () => {
    const first = [item('route-3', '2026-08-31T12:00:00.000Z')];
    const page = mergeFeedPage(first, [
      item('route-3', '2026-08-31T12:00:00.000Z'),
      item('route-2', '2026-08-30T12:00:00.000Z'),
    ], 3);

    assert.deepEqual(page.items.map(({ route_id }) => route_id), ['route-3', 'route-2']);
    assert.equal(page.hasMore, false);
  });

  it('ends pagination without manufacturing a cursor for an empty page', () => {
    const page = mergeFeedPage([item('route-1', '2026-08-29T12:00:00.000Z')], [], 20);
    assert.equal(page.cursor, null);
    assert.equal(page.hasMore, false);
  });
});

describe('following feed enrichment', () => {
  const routes = [
    { id: 'route-2', wall_id: 'wall-1', name: 'Crux Deluxe', grade_v: 'V6' },
    { id: 'route-1', wall_id: 'wall-1', name: 'Warm Up', grade_v: 'V2' },
  ] as Route[];
  const walls = [{ id: 'wall-1', name: 'North Cave' }] as Wall[];

  it('preserves feed order while attaching route and wall details', () => {
    const enriched = enrichFeedItems([
      item('route-1', '2026-08-31T12:00:00.000Z'),
      item('route-2', '2026-08-30T12:00:00.000Z'),
    ], routes, walls);

    assert.deepEqual(enriched.map(({ route }) => route?.name), ['Warm Up', 'Crux Deluxe']);
    assert.deepEqual(enriched.map(({ wall }) => wall?.name), ['North Cave', 'North Cave']);
  });

  it('keeps an unavailable route in feed order without exposing fabricated details', () => {
    const enriched = enrichFeedItems([
      item('missing-route', '2026-08-31T12:00:00.000Z'),
      item('route-1', '2026-08-30T12:00:00.000Z'),
    ], routes, walls);

    assert.deepEqual(enriched.map(({ route_id }) => route_id), ['missing-route', 'route-1']);
    assert.equal(enriched[0].route, undefined);
    assert.equal(enriched[0].wall, undefined);
  });
});
