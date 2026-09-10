import { Suspense } from 'react';
import type { Metadata } from 'next';
import { Flow } from '@/components/boarded/Flow';
import { getScreenTitle } from '@/lib/boarded/titles';

export async function generateMetadata({
  params,
}: {
  params: Promise<{ screen?: string[] }>;
}): Promise<Metadata> {
  const resolved = await params;
  const screen = resolved?.screen || [];

  return {
    title: getScreenTitle(screen),
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
