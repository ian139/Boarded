'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import type { Route } from '@boarded/shared/types';
import { calculateDisplayGrade } from '@boarded/shared/utils/grades';
import { RouteViewerDialog } from '@/components/home/RouteViewerDialog';
import { enrichFeedItems } from '@/lib/social/feed';
import { useFeedStore } from '@/lib/stores/feed-store';
import { useRoutesStore } from '@/lib/stores/routes-store';
import { useUserStore } from '@/lib/stores/user-store';
import { useWallsStore } from '@/lib/stores/walls-store';

function formatActivityTime(value: string) {
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value));
}

export default function ActivityPage() {
  const { user, isAuthenticated, isLoading: authLoading } = useUserStore();
  const { userId: feedUserId, items: storedItems, status, error, hasMore, load, loadMore, retry, reset } = useFeedStore();
  const { routes, fetchRoutes } = useRoutesStore();
  const { walls, fetchWalls } = useWallsStore();
  const [routeToView, setRouteToView] = useState<Route | null>(null);
  const userId = user?.id ?? null;
  const items = feedUserId === userId ? storedItems : [];

  useEffect(() => {
    if (!isAuthenticated || !userId) {
      reset();
      return;
    }
    if (feedUserId !== userId) void load(userId);
  }, [feedUserId, isAuthenticated, load, reset, userId]);

  useEffect(() => {
    if (!isAuthenticated || !userId) return;
    void Promise.all([fetchRoutes(), fetchWalls()]);
  }, [fetchRoutes, fetchWalls, isAuthenticated, userId]);

  const enrichedItems = useMemo(
    () => enrichFeedItems(items, routes, walls),
    [items, routes, walls],
  );

  const loadingInitial = authLoading || (status === 'loading' && items.length === 0);

  return (
    <div className="app-shell min-h-dvh pb-28 md:pb-12">
      <header className="page-header">
        <div className="page-frame flex min-h-16 items-center justify-between px-5 md:px-6">
          <Link href="/" className="wordmark" aria-label="Boarded home">Boarded</Link>
          <span className="eyebrow">Following</span>
        </div>
      </header>
      <main className="content-container py-8 md:py-12">
        <div className="mb-8 max-w-[68ch]">
          <p className="eyebrow mb-2">ACTIVITY</p>
          <h1 className="display-title">The routes your crew boarded.</h1>
          <p className="mt-3 text-secondary">A chronological field log from climbers you follow.</p>
        </div>

        {!isAuthenticated && !authLoading ? (
          <section className="empty-state" aria-labelledby="activity-sign-in">
            <div className="route-motif" aria-hidden="true" />
            <h2 id="activity-sign-in" className="display-subtitle">Find your climbing line.</h2>
            <p>Sign in to follow climbers and see their latest public routes.</p>
            <Link className="button-primary mt-5" href="/login">Sign in</Link>
          </section>
        ) : loadingInitial ? (
          <div className="feed-list" aria-label="Loading following activity" aria-busy="true">
            {[0, 1, 2].map((item) => <div key={item} className="feed-skeleton" />)}
          </div>
        ) : error && items.length === 0 ? (
          <section className="status-panel" role="alert">
            <p className="font-semibold">Activity could not be loaded</p>
            <p className="text-secondary mt-1">{error}</p>
            <button className="button-secondary mt-4" onClick={() => userId && void retry(userId)}>Try again</button>
          </section>
        ) : items.length === 0 ? (
          <section className="empty-state">
            <div className="route-motif" aria-hidden="true" />
            <h2 className="display-subtitle">The wall is quiet—for now.</h2>
            <p>Follow another climber to see their public routes here.</p>
            <Link className="button-secondary mt-5" href="/profile">View your profile</Link>
          </section>
        ) : (
          <>
            <ol className="feed-list" aria-label="Following activity">
              {enrichedItems.map((item) => {
                const { route, wall } = item;
                const grade = route
                  ? calculateDisplayGrade(route.grade_v, route.ascents) || route.grade_font
                  : undefined;
                return (
                  <li key={item.route_id}>
                    {route ? (
                      <button className="feed-row w-full text-left" onClick={() => setRouteToView(route)}>
                        <span className="route-node" aria-hidden="true" />
                        <span className="min-w-0">
                          <span className="block font-semibold text-primary">@{item.author_username || 'climber'} boarded {route.name}</span>
                          <time className="text-tertiary text-sm" dateTime={item.activity_at}>{formatActivityTime(item.activity_at)}</time>
                        </span>
                        <span className="feed-metadata text-right text-sm">
                          {grade && <span className="block font-semibold text-primary">{grade}</span>}
                          {wall?.name && <span className="block text-tertiary">{wall.name}</span>}
                        </span>
                      </button>
                    ) : (
                      <div className="feed-row">
                        <span className="route-node" aria-hidden="true" />
                        <span className="min-w-0">
                          <span className="block font-semibold text-primary">@{item.author_username || 'climber'} boarded a route</span>
                          <time className="text-tertiary text-sm" dateTime={item.activity_at}>{formatActivityTime(item.activity_at)}</time>
                        </span>
                        <span className="feed-metadata text-tertiary text-sm">Route unavailable</span>
                      </div>
                    )}
                  </li>
                );
              })}
            </ol>
            {error && (
              <div className="status-panel mt-5" role="alert">
                <p>{error}</p>
                <button className="button-secondary mt-3" onClick={() => userId && void retry(userId)}>Retry load more</button>
              </div>
            )}
            {hasMore && !error && (
              <button className="button-secondary mx-auto mt-6 flex" disabled={status === 'loading'} onClick={() => userId && void loadMore(userId)}>
                {status === 'loading' ? 'Loading activity…' : 'Load more'}
              </button>
            )}
            {!hasMore && <p className="mt-6 text-center text-tertiary">You’ve reached the start of the line.</p>}
          </>
        )}
        <RouteViewerDialog
          route={routeToView}
          onOpenChange={(open) => {
            if (!open) setRouteToView(null);
          }}
          wallImageUrl={
            routeToView
              ? routeToView.wall_image_url || walls.find((wall) => wall.id === routeToView.wall_id)?.image_url || ''
              : ''
          }
        />
      </main>
    </div>
  );
}
