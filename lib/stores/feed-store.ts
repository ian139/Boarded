'use client';

import { create, type StateCreator } from 'zustand';
import type { FollowingFeedItem } from '@boarded/shared/types';
import { getFollowingFeed } from '../social/api';
import { mergeFeedPage, type FeedCursor } from '../social/feed';

const PAGE_SIZE = 20;
type FeedFetcher = (cursor: FeedCursor | null, limit: number) => Promise<FollowingFeedItem[]>;

type FeedStatus = 'idle' | 'loading' | 'ready' | 'error';

export interface FeedState {
  userId: string | null;
  generation: number;
  items: FollowingFeedItem[];
  cursor: FeedCursor | null;
  hasMore: boolean;
  status: FeedStatus;
  error: string | null;
  load: (userId: string) => Promise<void>;
  loadMore: (userId: string) => Promise<void>;
  retry: (userId: string) => Promise<void>;
  reset: () => void;
}

async function requestPage(
  userId: string,
  generation: number,
  cursor: FeedCursor | null,
  current: FollowingFeedItem[],
  set: (state: Partial<FeedState>) => void,
  get: () => FeedState,
  fetchPage: FeedFetcher,
) {
  set({ status: 'loading', error: null });
  try {
    const incoming = await fetchPage(cursor, PAGE_SIZE);
    if (get().userId !== userId || get().generation !== generation) return;
    const page = mergeFeedPage(current, incoming, PAGE_SIZE);
    set({ ...page, status: 'ready', error: null });
  } catch (error) {
    if (get().userId !== userId || get().generation !== generation) return;
    set({
      status: 'error',
      error: typeof navigator !== 'undefined' && !navigator.onLine
        ? 'You are offline. Reconnect to refresh activity.'
        : error instanceof Error ? error.message : 'Unable to load activity.',
    });
  }
}

export function createFeedState(fetchPage: FeedFetcher = getFollowingFeed): StateCreator<FeedState> {
  return (set, get) => ({
    userId: null,
    generation: 0,
    items: [],
    cursor: null,
    hasMore: true,
    status: 'idle',
    error: null,
    load: async (userId) => {
      const state = get();
      const generation = state.userId === userId ? state.generation : state.generation + 1;
      if (state.userId !== userId) {
        set({
          userId,
          generation,
          items: [],
          cursor: null,
          hasMore: true,
          status: 'idle',
          error: null,
        });
      }
      await requestPage(userId, generation, null, [], set, get, fetchPage);
    },
    loadMore: async (userId) => {
      const state = get();
      if (state.userId !== userId || state.status === 'loading' || !state.hasMore || !state.cursor) return;
      await requestPage(userId, state.generation, state.cursor, state.items, set, get, fetchPage);
    },
    retry: async (userId) => {
      const state = get();
      if (state.userId !== userId) {
        await get().load(userId);
        return;
      }
      await requestPage(
        userId,
        state.generation,
        state.items.length ? state.cursor : null,
        state.items,
        set,
        get,
        fetchPage,
      );
    },
    reset: () => set((state) => ({
      userId: null,
      generation: state.generation + 1,
      items: [],
      cursor: null,
      hasMore: true,
      status: 'idle',
      error: null,
    })),
  });
}

export const useFeedStore = create<FeedState>(createFeedState());
