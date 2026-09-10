/**
 * Single source of truth for journal screen titles (F5).
 *
 * Consumed by BOTH `app/app/[...screen]/page.tsx` generateMetadata (server
 * render / initial document title) and `components/boarded/Shell.tsx` (client
 * navigation), so client navigation can no longer clobber a server-computed
 * dynamic title like "Redpoint Ridge (5.12a) — Boarded" with a generic string.
 */
import { routes } from './journal.ts';

export function getScreenTitle(screen: readonly string[]): string {
  const count = screen.length;
  const segment = screen[0] || '';
  const param = screen[1] || '';

  if (count === 0) return 'Feed — Boarded';

  if (segment === 'explore' && count === 1) return 'Explore — Boarded';
  if (segment === 'log' && count === 1) return 'Log an attempt — Boarded';
  if (segment === 'activity' && count === 1) return 'Activity — Boarded';
  if (segment === 'profile' && count === 1) return 'Profile — Boarded';

  if (segment === 'send' && count === 2 && param) {
    return param === 'maya-redpoint' ? "Maya's send — Boarded" : 'Send report — Boarded';
  }

  if (segment === 'route' && count === 2 && param) {
    const route = routes.find((r) => r.id === param);
    return route ? `${route.name} (${route.grade}) — Boarded` : 'Route not found — Boarded';
  }

  if (segment === 'attempt' && count === 2 && param) return 'Your attempt — Boarded';
  if (segment === 'share' && count === 2 && param) return 'Share your result — Boarded';
  if (segment === 'climber' && count === 2 && param) {
    return param === 'maya' || param === 'maya-k' ? 'Maya K. — Boarded' : 'Climber profile — Boarded';
  }

  return 'Page not found — Boarded';
}

/**
 * Client-navigation variant: derives journal screen segments from a pathname.
 *
 * `usePathname` returns the raw encoded URL path while `generateMetadata`
 * receives decoded dynamic params, so each segment is decoded here before
 * lookup. Splitting happens BEFORE decoding so an encoded `%2F` stays part of
 * one segment, and malformed percent-encoding falls back to the raw segment
 * instead of throwing.
 */
export function getRouteTitle(pathname: string | null | undefined): string {
  const screen = (pathname || '')
    .replace(/^\/app\/?/, '')
    .split('/')
    .filter(Boolean)
    .map((segment) => {
      try {
        return decodeURIComponent(segment);
      } catch {
        return segment; // malformed percent-encoding: keep the raw segment
      }
    });
  return getScreenTitle(screen);
}
