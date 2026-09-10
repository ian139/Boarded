'use client';

import { useEffect, useRef } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useJournal } from '@/lib/boarded/store';
import { getRouteTitle } from '@/lib/boarded/titles';

interface NavItem {
  href: string;
  label: string;
  icon: (active: boolean) => React.ReactNode;
}

const NAV_ITEMS: NavItem[] = [
  {
    href: '/app',
    label: 'Feed',
    icon: (active: boolean) => (
      <svg className="b-nav-icon" fill={active ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={active ? 0 : 1.75} aria-hidden="true">
        <path strokeLinecap="round" strokeLinejoin="round" d="m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" />
      </svg>
    ),
  },
  {
    href: '/app/explore',
    label: 'Explore',
    icon: (active: boolean) => (
      <svg className="b-nav-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={active ? 2.5 : 1.75} aria-hidden="true">
        <path strokeLinecap="round" strokeLinejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
      </svg>
    ),
  },
  {
    href: '/app/log',
    label: 'Log',
    icon: (active: boolean) => (
      <svg className="b-nav-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={active ? 2.5 : 1.75} aria-hidden="true">
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
      </svg>
    ),
  },
  {
    href: '/app/activity',
    label: 'Activity',
    icon: (active: boolean) => (
      <svg className="b-nav-icon" fill={active ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={active ? 0 : 1.75} aria-hidden="true">
        <path strokeLinecap="round" strokeLinejoin="round" d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0" />
      </svg>
    ),
  },
  {
    href: '/app/profile',
    label: 'Profile',
    icon: (active: boolean) => (
      <svg className="b-nav-icon" fill={active ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={active ? 0 : 1.75} aria-hidden="true">
        <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
      </svg>
    ),
  },
];

// Route titles come from the shared map (lib/boarded/titles.ts) also used by
// generateMetadata, so client navigation never discards dynamic server titles.

interface FocusDescriptor {
  id?: string;
  href?: string;
  hrefIndex?: number;
  selector?: string;
  selectorIndex?: number;
}

function getElementByHash(hash: string): HTMLElement | null {
  if (!hash || hash.length <= 1) return null;
  const rawId = hash.startsWith('#') ? hash.slice(1) : hash;
  try {
    const decodedId = decodeURIComponent(rawId);
    return document.getElementById(decodedId) || document.getElementById(rawId);
  } catch {
    try {
      return document.getElementById(rawId);
    } catch {
      return null;
    }
  }
}

function prepareFocusableHashTarget(el: HTMLElement): void {
  if (el.hasAttribute('tabindex')) return;
  const isAnchor = el.tagName === 'A' || el.tagName === 'AREA';
  const isNativelyFocusable = isAnchor ? el.hasAttribute('href') : el.tabIndex >= 0;
  if (!isNativelyFocusable) {
    el.setAttribute('tabIndex', '-1');
  }
}

function getDestinationMarker(container: HTMLElement, pathname: string): HTMLElement | null {
  const normalized = pathname.endsWith('/') && pathname.length > 1 ? pathname.slice(0, -1) : pathname;
  return (
    container.querySelector<HTMLElement>(`[data-boarded-path="${normalized}"]`) ||
    container.querySelector<HTMLElement>(`[data-boarded-path="${pathname}"]`) ||
    null
  );
}

function captureControlDescriptor(el: Element, container: HTMLElement): FocusDescriptor | null {
  if (!el || el === document.body || el === container) return null;
  if (el.id) {
    return { id: el.id };
  }
  const href = el.getAttribute('href');
  if (href) {
    const anchors = Array.from(container.querySelectorAll('a'));
    const matching = anchors.filter((a) => a.getAttribute('href') === href);
    const hrefIndex = matching.indexOf(el as HTMLAnchorElement);
    return { href, hrefIndex: hrefIndex >= 0 ? hrefIndex : 0 };
  }
  const tagName = el.tagName.toLowerCase();
  const ariaLabel = el.getAttribute('aria-label');
  if (ariaLabel) {
    try {
      const escaped = typeof CSS !== 'undefined' && CSS.escape ? CSS.escape(ariaLabel) : ariaLabel;
      const selector = `${tagName}[aria-label="${escaped}"]`;
      const matching = Array.from(container.querySelectorAll(selector));
      const selectorIndex = matching.indexOf(el);
      return { selector, selectorIndex: selectorIndex >= 0 ? selectorIndex : 0 };
    } catch {
      // ignore selector syntax errors
    }
  }
  return null;
}

function resolveControlDescriptor(desc: FocusDescriptor, scope: HTMLElement): HTMLElement | null {
  if (desc.id) {
    const el = document.getElementById(desc.id);
    if (el && scope.contains(el)) return el;
  }
  if (desc.href) {
    const anchors = Array.from(scope.querySelectorAll<HTMLElement>('a'));
    const matching = anchors.filter((a) => a.getAttribute('href') === desc.href);
    const index = desc.hrefIndex ?? 0;
    if (matching[index]) return matching[index];
    if (matching.length > 0) return matching[0];
  }
  if (desc.selector) {
    try {
      const matching = Array.from(scope.querySelectorAll<HTMLElement>(desc.selector));
      const index = desc.selectorIndex ?? 0;
      if (matching[index]) return matching[index];
      if (matching.length > 0) return matching[0];
    } catch {
      // ignore selector syntax errors
    }
  }
  return null;
}

/** Focus the destination heading (accessible route-entry focus target). */
function focusDestinationHeading(marker: HTMLElement): boolean {
  const heading = marker.querySelector<HTMLElement>('h1');
  if (!heading) return false; // Still waiting for heading in marker
  heading.setAttribute('tabIndex', '-1');
  heading.focus({ preventScroll: true });
  return true;
}

export function Shell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const mainRef = useRef<HTMLElement>(null);
  const isPopstateRef = useRef<boolean>(false);
  const userInteractedRef = useRef<boolean>(false);
  const locationFocusMapRef = useRef<Map<string, FocusDescriptor>>(new Map());
  const lastPathnameRef = useRef<string>(pathname);
  const initialize = useJournal((s) => s.initialize);
  const error = useJournal((s) => s.error);
  const retryStorage = useJournal((s) => s.retryStorage);

  useEffect(() => {
    initialize();
  }, [initialize]);

  // Set route-derived descriptive title
  useEffect(() => {
    if (typeof document !== 'undefined') {
      document.title = getRouteTitle(pathname);
    }
  }, [pathname]);

  // Track user focus and interaction to capture control descriptors
  useEffect(() => {
    const captureInteractiveTarget = (target: Element | null) => {
      if (!target || !mainRef.current || !mainRef.current.contains(target)) return;
      const control = target.closest('a, button, input, textarea, select, [tabindex]:not([tabindex="-1"])');
      if (control && mainRef.current.contains(control)) {
        const desc = captureControlDescriptor(control, mainRef.current);
        if (desc) {
          locationFocusMapRef.current.set(pathname, desc);
        }
      }
    };

    const handleFocusIn = (event: FocusEvent) => {
      captureInteractiveTarget(event.target as Element | null);
    };

    const handlePointerDown = (event: PointerEvent) => {
      userInteractedRef.current = true;
      captureInteractiveTarget(event.target as Element | null);
    };

    const handleKeyDown = () => {
      userInteractedRef.current = true;
    };

    window.addEventListener('focusin', handleFocusIn, true);
    window.addEventListener('pointerdown', handlePointerDown, true);
    window.addEventListener('keydown', handleKeyDown, true);

    return () => {
      window.removeEventListener('focusin', handleFocusIn, true);
      window.removeEventListener('pointerdown', handlePointerDown, true);
      window.removeEventListener('keydown', handleKeyDown, true);
    };
  }, [pathname]);

  // Track popstate (browser back/forward)
  useEffect(() => {
    const handlePopstate = () => {
      isPopstateRef.current = true;
      userInteractedRef.current = false;
    };
    window.addEventListener('popstate', handlePopstate);
    return () => window.removeEventListener('popstate', handlePopstate);
  }, []);

  // Route focus announcement and management
  useEffect(() => {
    const isPop = isPopstateRef.current;
    isPopstateRef.current = false;
    userInteractedRef.current = false;

    // If navigating away, save current focused control if any
    if (lastPathnameRef.current !== pathname && typeof document !== 'undefined') {
      const active = document.activeElement;
      if (active && mainRef.current && mainRef.current.contains(active)) {
        const desc = captureControlDescriptor(active, mainRef.current);
        if (desc) {
          locationFocusMapRef.current.set(lastPathnameRef.current, desc);
        }
      }
      lastPathnameRef.current = pathname;
    }
    const tryFocusHashTarget = (): boolean => {
      if (typeof window === 'undefined' || !window.location.hash) return false;
      const hashEl = getElementByHash(window.location.hash);
      if (!hashEl) return false;
      prepareFocusableHashTarget(hashEl);
      hashEl.scrollIntoView({ behavior: 'auto', block: 'start' });
      hashEl.focus({ preventScroll: true });
      return true;
    };

    const tryApplyFocus = (): boolean => {
      if (!mainRef.current) return false;
      if (userInteractedRef.current) return true; // User interacted, don't steal focus

      // If explicit fragment is present, prioritize it
      if (typeof window !== 'undefined' && window.location.hash) {
        if (tryFocusHashTarget()) return true;
      }
      const marker = getDestinationMarker(mainRef.current, pathname);
      if (!marker) {
        // Destination marker for current path not mounted yet; wait
        return false;
      }

      if (isPop) {
        // Browser back/forward restoration
        const active = typeof document !== 'undefined' ? document.activeElement : null;
        const hasLiveFocus = active && active !== document.body && active !== document.documentElement && marker.contains(active);
        if (hasLiveFocus) {
          return true; // Browser genuinely restored live focus
        }

        // Try restoring stored control for this location
        const storedDesc = locationFocusMapRef.current.get(pathname);
        if (storedDesc) {
          const matchingControl =
            resolveControlDescriptor(storedDesc, marker) ||
            (mainRef.current ? resolveControlDescriptor(storedDesc, mainRef.current) : null);
          if (matchingControl) {
            matchingControl.focus({ preventScroll: true });
            return true;
          }
        }
        if (!focusDestinationHeading(marker)) return false;
        return true;
      }

      // Forward / standard navigation
      if (typeof window === 'undefined' || !window.location.hash) {
        if (!focusDestinationHeading(marker)) return false;
        return true;
      }

      return false;
    };

    // Immediate attempt
    if (tryApplyFocus()) {
      return;
    }

    // If child is suspended or mounting asynchronously, wait via bounded MutationObserver
    let observer: MutationObserver | null = null;
    let timeoutId: number | null = null;

    const cleanup = () => {
      if (observer) {
        observer.disconnect();
        observer = null;
      }
      if (timeoutId) {
        clearTimeout(timeoutId);
        timeoutId = null;
      }
    };

    if (mainRef.current) {
      observer = new MutationObserver(() => {
        if (tryApplyFocus()) {
          cleanup();
        }
      });

      observer.observe(mainRef.current, {
        childList: true,
        subtree: true,
      });
    }

    // Fallback: disconnect after 1500ms and apply final focus attempt
    timeoutId = window.setTimeout(() => {
      cleanup();
      if (!userInteractedRef.current && mainRef.current) {
        if (typeof window !== 'undefined' && window.location.hash && tryFocusHashTarget()) return;
        const marker = getDestinationMarker(mainRef.current, pathname);
        const scope = marker || mainRef.current;
        const heading = scope.querySelector<HTMLElement>('h1');
        if (heading) {
          heading.setAttribute('tabIndex', '-1');
          heading.focus({ preventScroll: true });
        } else {
          mainRef.current.focus({ preventScroll: true });
        }
      }
    }, 1500);

    return cleanup;
  }, [pathname]);

  // Handle intra-page hash changes (e.g. #comments, #share)
  useEffect(() => {
    const handleHash = () => {
      if (typeof window !== 'undefined' && window.location.hash) {
        const hashEl = getElementByHash(window.location.hash);
        if (hashEl) {
          prepareFocusableHashTarget(hashEl);
          hashEl.focus({ preventScroll: false });
        }
      }
    };
    window.addEventListener('hashchange', handleHash);
    return () => window.removeEventListener('hashchange', handleHash);
  }, []);
  return (
    <div className="boarded">
      {/* Accessible Skip Link */}
      <a href="#main-content" className="b-skip-link">
        Skip to main content
      </a>

      {/* Slim Mobile Brand Header */}
      <header className="b-mobile-header" role="banner">
        <Link href="/" className="b-brand-logo text-xl inline-flex items-center min-h-[44px]">
          Boarded
        </Link>
        <span className="b-eyebrow">Climbing Journal</span>
      </header>

      <div className="b-shell-layout">
        {/* Desktop Sidebar Navigation */}
        <nav className="b-desktop-nav" aria-label="Primary application navigation">
          <Link href="/" className="b-brand-link inline-flex items-center min-h-[44px]">
            <span className="b-brand-logo">Boarded</span>
          </Link>

          <ul className="b-nav-list" role="list">
            {NAV_ITEMS.map((item) => {
              const isActive = pathname === item.href;
              return (
                <li key={item.href} className="b-nav-item">
                  <Link
                    href={item.href}
                    className="b-nav-link"
                    aria-current={isActive ? 'page' : undefined}
                  >
                    {item.icon(isActive)}
                    <span>{item.label}</span>
                  </Link>
                </li>
              );
            })}
          </ul>

          <div className="mt-8 pt-6 border-t border-[rgba(244,242,235,0.08)] flex flex-col gap-3">
            <Link href="/app/log" className="b-button b-button-primary w-full justify-center">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5} aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              <span>Log attempt</span>
            </Link>
          </div>
        </nav>

        {/* Single Primary Landmark */}
        <main id="main-content" ref={mainRef} className="b-main" tabIndex={-1}>
          {/* Persistent Live Region for Storage Alerts */}
          {error && (
            <div className="w-full max-w-[680px]" role="region" aria-label="System status">
              <div className="b-live-alert" role="alert" aria-live="polite">
                <div className="flex items-center gap-2">
                  <svg className="w-5 h-5 text-[#FF5C5C] flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
                  </svg>
                  <span>{error}</span>
                </div>
                <button
                  type="button"
                  onClick={retryStorage}
                  className="b-button text-xs py-1 px-3 min-h-[36px]"
                >
                  Retry
                </button>
              </div>
            </div>
          )}

          {children}
        </main>
      </div>

      {/* Reachable Mobile Bottom Navigation (5 destinations) */}
      <nav className="b-mobile-nav" aria-label="Mobile navigation">
        {NAV_ITEMS.map((item) => {
          const isActive = pathname === item.href;
          const isPrimary = item.href === '/app/log';
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`b-mobile-nav-link ${isPrimary ? 'b-mobile-nav-primary' : ''}`}
              data-primary={isPrimary ? 'true' : undefined}
              aria-current={isActive ? 'page' : undefined}
            >
              {item.icon(isActive || isPrimary)}
              <span className="b-mobile-nav-label">{item.label}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
