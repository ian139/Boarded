import { Suspense } from 'react';
import type { Metadata } from 'next';
import { Flow } from '@/components/boarded/Flow';
import { routes } from '@/lib/boarded/journal';

export async function generateMetadata({
  params,
}: {
  params: Promise<{ screen?: string[] }>;
}): Promise<Metadata> {
  const resolved = await params;
  const screen = resolved?.screen || [];
  const count = screen.length;
  const segment = screen[0] || '';
  const param = screen[1] || '';

  let title = 'Boarded — Climbing Journal';

  if (segment === 'explore' && count === 1) {
    title = 'Explore — Boarded';
  } else if (segment === 'log' && count === 1) {
    title = 'Log an attempt — Boarded';
  } else if (segment === 'activity' && count === 1) {
    title = 'Activity — Boarded';
  } else if (segment === 'profile' && count === 1) {
    title = 'Profile — Boarded';
  } else if (segment === 'send' && count === 2 && param) {
    title = param === 'maya-redpoint' ? "Maya's send — Boarded" : 'Send report — Boarded';
  } else if (segment === 'route' && count === 2 && param) {
    const route = routes.find((r) => r.id === param);
    title = route ? `${route.name} (${route.grade}) — Boarded` : 'Route not found — Boarded';
  } else if (segment === 'attempt' && count === 2 && param) {
    title = 'Your attempt — Boarded';
  } else if (segment === 'share' && count === 2 && param) {
    title = 'Share your result — Boarded';
  } else if (segment === 'climber' && count === 2 && param) {
    title = (param === 'maya' || param === 'maya-k') ? 'Maya K. — Boarded' : 'Climber profile — Boarded';
  } else {
    title = 'Page not found — Boarded';
  }

  return {
    title,
    description: 'Editorial rock climbing journal for logging attempts, tracking sends, and exploring routes.',
  };
}

export default async function ScreenPage({
  params,
  searchParams,
}: {
  params: Promise<{ screen: string[] }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const resolvedParams = await params;
  const resolvedSearchParams = await searchParams;
  const screen = resolvedParams?.screen || [];
  const canonicalPath = screen.length > 0 ? `/app/${screen.join('/')}` : '/app';

  return (
    <div data-boarded-path={canonicalPath} style={{ display: 'contents' }}>
      <Suspense
        fallback={
          <div className="b-page" aria-busy="true">
            <div className="b-panel text-center py-12">
              <p className="b-muted text-sm">Loading climbing journal...</p>
            </div>
          </div>
        }
      >
        <Flow screen={resolvedParams.screen} searchParams={resolvedSearchParams} />
      </Suspense>
    </div>
  );
}
