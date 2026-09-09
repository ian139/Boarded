'use client';

import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { SendDetail, RouteDetail, AttemptDetail } from '@/components/boarded/Details';
import { LogAttemptForm, ShareFlow, ProfileScreen } from '@/components/boarded/LogFlow';
import { ExploreScreen, ActivityScreen, ClimberProfile } from '@/components/boarded/Community';
import './flow.css';

export interface FlowProps {
  screen?: string[];
  searchParams?: Record<string, string | string[] | undefined>;
}

export function Flow({ screen = [], searchParams }: FlowProps) {
  // Read query params from props with navigation fallback for client-side transitions
  const navSearchParams = useSearchParams();

  const queryRoute = searchParams?.route;
  const initialRouteId =
    typeof queryRoute === 'string'
      ? queryRoute
      : Array.isArray(queryRoute)
      ? queryRoute[0]
      : navSearchParams?.get('route') || undefined;

  const count = screen.length;
  const segment = screen[0] || '';
  const param = screen[1] || '';

  // 1. Explore Screen (/app/explore) — requires exactly 1 segment
  if (segment === 'explore' && count === 1) {
    return <ExploreScreen />;
  }

  // 2. Log Attempt Screen (/app/log) — requires exactly 1 segment
  if (segment === 'log' && count === 1) {
    return <LogAttemptForm initialRouteId={initialRouteId} />;
  }

  // 3. Activity Screen (/app/activity) — requires exactly 1 segment
  if (segment === 'activity' && count === 1) {
    return <ActivityScreen />;
  }

  // 4. Profile Screen (/app/profile) — requires exactly 1 segment
  if (segment === 'profile' && count === 1) {
    return <ProfileScreen />;
  }

  // 5. Send Detail Screen (/app/send/[id]) — requires exactly 2 segments
  if (segment === 'send' && count === 2 && param) {
    return <SendDetail postId={param} />;
  }

  // 6. Route Detail Screen (/app/route/[routeId]) — requires exactly 2 segments
  if (segment === 'route' && count === 2 && param) {
    return <RouteDetail routeId={param} />;
  }

  // 7. Attempt Detail Screen (/app/attempt/[id]) — requires exactly 2 segments
  if (segment === 'attempt' && count === 2 && param) {
    return <AttemptDetail entryId={param} />;
  }

  // 8. Share Result Screen (/app/share/[id]) — requires exactly 2 segments
  if (segment === 'share' && count === 2 && param) {
    return <ShareFlow entryId={param} />;
  }

  // 9. Climber Profile Screen (/app/climber/[id]) — requires exactly 2 segments
  if (segment === 'climber' && count === 2 && param) {
    return <ClimberProfile climberId={param} />;
  }
  // 10. Not Found Recovery
  const pathDisplay = `/app/${screen.join('/')}`;

  return (
    <article className="b-page" aria-labelledby="notfound-title">
      <div className="b-page-header">
        <Link href="/app" className="b-button b-button-ghost">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
            <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
          </svg>
          Back to Feed
        </Link>
        <span className="b-eyebrow">404 <span aria-hidden="true">·</span> Unrecognized Path</span>
      </div>

      <div className="b-panel b-stack">
        <div>
          <div className="b-eyebrow text-stone-400 mb-1">Route Navigation</div>
          <h1 id="notfound-title" className="b-serif text-3xl font-semibold italic text-stone-100">
            Page Not Found
          </h1>
          <p className="b-muted text-sm mt-1">
            The path <code className="text-stone-300 font-mono text-xs bg-stone-900 px-2 py-0.5 rounded border border-stone-800">{pathDisplay}</code> is not a recognized Boarded view.
          </p>
        </div>

        <div className="b-shelf b-stack">
          <h2 className="text-xs font-bold uppercase tracking-wider text-stone-400">
            Quick Recovery Destinations
          </h2>
          <ul className="text-sm space-y-2 text-stone-300">
            <li>
              <Link href="/app" className="text-indigo-400 hover:underline font-semibold">
                Feed
              </Link>{' '}
              — View Maya K.&apos;s send and community ticks.
            </li>
            <li>
              <Link href="/app/explore" className="text-indigo-400 hover:underline font-semibold">
                Explore Directory
              </Link>{' '}
              — Browse crags, routes, and climber profiles.
            </li>
            <li>
              <Link href="/app/log" className="text-indigo-400 hover:underline font-semibold">
                Log an Attempt
              </Link>{' '}
              — Record your latest session.
            </li>
            <li>
              <Link href="/app/profile" className="text-indigo-400 hover:underline font-semibold">
                Your Profile
              </Link>{' '}
              — Check your stats, entries, and saved routes.
            </li>
          </ul>
        </div>

        <div className="b-inline pt-2 border-t border-stone-800">
          <Link href="/app" className="b-button b-button-primary">
            Return to Feed
          </Link>
          <Link href="/app/explore" className="b-button">
            Browse Directory
          </Link>
        </div>
      </div>
    </article>
  );
}

export default Flow;
