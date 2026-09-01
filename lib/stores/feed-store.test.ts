import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createStore } from 'zustand/vanilla';
import type { FollowingFeedItem } from '@boarded/shared/types';
import { createFeedState } from './feed-store';

const item = (routeId: string): FollowingFeedItem => ({
  route_id: routeId,
  activity_at: '2026-08-31T12:00:00.000Z',
  author_id: `author-${routeId}`,
  author_username: 'climber',
});

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

describe('following feed account isolation', () => {
  it('clears the previous account and always requests the first page on switch', async () => {
    const cursors: unknown[] = [];
    const store = createStore(createFeedState(async (cursor) => {
      cursors.push(cursor);
      return [item(cursors.length === 1 ? 'alice-route' : 'bob-route')];
    }));

    await store.getState().load('alice');
    assert.deepEqual(store.getState().items.map(({ route_id }) => route_id), ['alice-route']);

    await store.getState().load('bob');
    assert.equal(store.getState().userId, 'bob');
    assert.deepEqual(store.getState().items.map(({ route_id }) => route_id), ['bob-route']);
    assert.deepEqual(cursors, [null, null]);
  });

  it('ignores late success and error completions from a previous account', async () => {
    const alice = deferred<FollowingFeedItem[]>();
    const bob = deferred<FollowingFeedItem[]>();
    let call = 0;
    const store = createStore(createFeedState(() => (++call === 1 ? alice.promise : bob.promise)));

    const aliceLoad = store.getState().load('alice');
    const bobLoad = store.getState().load('bob');
    bob.resolve([item('bob-route')]);
    await bobLoad;
    alice.resolve([item('alice-route')]);
    await aliceLoad;

    assert.equal(store.getState().userId, 'bob');
    assert.deepEqual(store.getState().items.map(({ route_id }) => route_id), ['bob-route']);
    assert.equal(store.getState().error, null);

    const staleError = deferred<FollowingFeedItem[]>();
    const current = deferred<FollowingFeedItem[]>();
    call = 0;
    const errorStore = createStore(createFeedState(() => (++call === 1 ? staleError.promise : current.promise)));
    const staleLoad = errorStore.getState().load('alice');
    const currentLoad = errorStore.getState().load('bob');
    current.resolve([item('bob-route')]);
    await currentLoad;
    staleError.reject(new Error('alice failed'));
    await staleLoad;

    assert.deepEqual(errorStore.getState().items.map(({ route_id }) => route_id), ['bob-route']);
    assert.equal(errorStore.getState().error, null);
  });
});
