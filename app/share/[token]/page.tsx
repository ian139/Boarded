'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { resourceAPI } from '@/lib/api/client';
import type { Route } from '@boarded/shared/types';
import { calculateDisplayGrade, normalizeRouteGrades } from '@boarded/shared/utils/grades';
import { RouteViewer } from '@/components/original-board/wall/RouteViewer';
import { DEFAULT_WALL } from '@/lib/stores/walls-store';

export default function SharePage() {
  const params = useParams();
  const token = typeof params?.token === 'string' ? params.token : '';
  const [route, setRoute] = useState<Route | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    setRoute(null);
    setError(null);
    setIsLoading(true);

    const load = async () => {
      if (!token) {
        setError('Invalid share link');
        setIsLoading(false);
        return;
      }

      try {
        const sharedRoute = await resourceAPI.request<Route>(`/api/share/${encodeURIComponent(token)}`, {
          signal: controller.signal,
        });
        if (controller.signal.aborted) return;
        setRoute(normalizeRouteGrades(sharedRoute));
        setIsLoading(false);
        try {
          const result = await resourceAPI.request<{ view_count: number }>(
            `/api/routes/${encodeURIComponent(sharedRoute.id)}/views`,
            { method: 'POST', signal: controller.signal },
          );
          if (!controller.signal.aborted) {
            setRoute((current) => current?.id === sharedRoute.id ? { ...current, view_count: result.view_count } : current);
          }
        } catch {
          if (!controller.signal.aborted) console.warn('Unable to increment route view count');
        }
      } catch (err) {
        if (!controller.signal.aborted) {
          setError(err instanceof Error ? err.message : 'Failed to load route');
        }
      } finally {
        if (!controller.signal.aborted) setIsLoading(false);
      }
    };

    void load();
    return () => controller.abort();
  }, [token]);

  return (
    <div className="app-shell min-h-dvh pb-[calc(7rem+env(safe-area-inset-bottom))] md:pb-0">
      <header className="page-header px-4 md:px-8 pt-5 pb-4">
        <div className="flex items-center gap-3">
          <Link
            href="/"
            aria-label="Back to home"
            className="size-10 rounded-xl bg-muted/50 flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
          >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
            </svg>
          </Link>
          <h1 className="text-xl font-bold">Shared Route</h1>
        </div>
      </header>

      <main className="h-[calc(100dvh-80px)]">
        {isLoading ? (
          <div className="h-full flex items-center justify-center text-muted-foreground">Loading route...</div>
        ) : error ? (
          <div className="h-full flex items-center justify-center text-muted-foreground">{error}</div>
        ) : route ? (
          <RouteViewer
            wallImageUrl={route.wall_image_url || route.wall?.image_url || DEFAULT_WALL.image_url}
            wallImageWidth={route.wall_image_width || route.wall?.image_width || DEFAULT_WALL.image_width}
            wallImageHeight={route.wall_image_height || route.wall?.image_height || DEFAULT_WALL.image_height}
            holds={route.holds}
            routeName={route.name}
            grade={calculateDisplayGrade(route.grade_v, route.ascents)}
            setterName={route.user_name}
            routeId={route.id}
            route={route}
            comments={route.comments || []}
          />
        ) : null}
      </main>
    </div>
  );
}
