'use client';

import { useState } from 'react';
import Link from 'next/link';
import { routes } from '@/lib/boarded/journal';
import { useShallow } from 'zustand/react/shallow';
import { useJournal } from '@/lib/boarded/store';

interface VenueItem {
  id: string;
  name: string;
  type: 'Outdoor Crag' | 'Indoor Climbing Gym';
  location: string;
  rockOrWall: string;
  routesCount: string;
  description: string;
  featuredRouteId?: string;
}

const VENUES: VenueItem[] = [
  {
    id: 'stonegate-crag',
    name: 'Stonegate Crag',
    type: 'Outdoor Crag',
    location: 'North Wall Canyon',
    rockOrWall: 'Pocketed Limestone',
    routesCount: '12 bolted lines · 5.10a - 5.13c',
    description:
      'Sustained overhanging limestone with natural pockets, edge seams, and pumpy endurance testpieces. Home to Redpoint Ridge.',
    featuredRouteId: 'redpoint-ridge',
  },
  {
    id: 'bishop-buttermilks',
    name: 'Bishop (Buttermilks)',
    type: 'Outdoor Crag',
    location: 'Eastern Sierra Basin',
    rockOrWall: 'Quartz Monzonite Granite',
    routesCount: '80+ boulder problems · V0 - V14',
    description:
      'Classic highball granite blocks known for razor crystals, compression roofs, friction slopers, and technical heel hooks.',
    featuredRouteId: 'steep-circuit',
  },
  {
    id: 'stone-summit-gym',
    name: 'Stone Summit Climbing Gym',
    type: 'Indoor Climbing Gym',
    location: 'Metro Indoor Facility',
    rockOrWall: 'Textured Plywood & Dual-Tex Macro Holds',
    routesCount: '60ft lead wall · 45° bouldering cave · 15 auto-belays',
    description:
      'Factual indoor training facility featuring adjustable hydraulic training boards, campus rungs, and competition circuit routes.',
  },
];

/* ==========================================================================
   1. Explore Screen (/app/explore)
   ========================================================================== */

export function ExploreScreen() {
  // Selective subscription (F13).
  const { savedRouteIds, toggleSave } = useJournal(
    useShallow((s) => ({ savedRouteIds: s.savedRouteIds, toggleSave: s.toggleSave }))
  );
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<'all' | 'routes' | 'venues' | 'climbers'>('all');

  const q = searchQuery.trim().toLowerCase();

  // Filter routes
  const filteredRoutes = routes.filter((r) => {
    if (activeFilter !== 'all' && activeFilter !== 'routes') return false;
    if (!q) return true;
    return (
      r.name.toLowerCase().includes(q) ||
      r.grade.toLowerCase().includes(q) ||
      r.crag.toLowerCase().includes(q) ||
      r.type.toLowerCase().includes(q) ||
      r.rock.toLowerCase().includes(q) ||
      r.style.toLowerCase().includes(q)
    );
  });

  // Filter venues
  const filteredVenues = VENUES.filter((v) => {
    if (activeFilter !== 'all' && activeFilter !== 'venues') return false;
    if (!q) return true;
    return (
      v.name.toLowerCase().includes(q) ||
      v.location.toLowerCase().includes(q) ||
      v.type.toLowerCase().includes(q) ||
      v.rockOrWall.toLowerCase().includes(q) ||
      v.description.toLowerCase().includes(q)
    );
  });

  // Climbers list
  const climbers = [
    {
      id: 'maya',
      name: 'Maya K.',
      role: 'Stonegate Local · 5.12 Climber',
      recentAscent: 'Redpoint Ridge (5.12a)',
      href: '/app/climber/maya',
    },
    {
      id: 'alex',
      name: 'Alex R. (You)',
      role: 'Journal Climber · Local Logbook',
      recentAscent: 'Active Sessions & Projects',
      href: '/app/profile',
    },
  ];

  const filteredClimbers = climbers.filter((c) => {
    if (activeFilter !== 'all' && activeFilter !== 'climbers') return false;
    if (!q) return true;
    return (
      c.name.toLowerCase().includes(q) ||
      c.role.toLowerCase().includes(q) ||
      c.recentAscent.toLowerCase().includes(q)
    );
  });

  const totalResults = filteredRoutes.length + filteredVenues.length + filteredClimbers.length;

  return (
    <article className="b-page" aria-labelledby="explore-heading">
      <div className="b-page-header">
        <span className="b-eyebrow">Climbing directory</span>
        <Link href="/app" className="b-button b-button-ghost">
          Back to Feed
        </Link>
      </div>

      <div className="b-panel b-stack">
        <div>
          <div className="b-eyebrow text-stone-400 mb-1">Local Directory</div>
          <h1 id="explore-heading" className="b-serif text-3xl sm:text-4xl font-semibold italic text-stone-100">
            Explore Routes, Venues & Climbers
          </h1>
          <p className="b-muted text-sm mt-1">
            Search rock climbing testpieces, crags, indoor training facilities, and local climbers.
          </p>
        </div>

        {/* Real Local Search Input */}
        <div className="b-search-row">
          <div className="flex-1 min-w-0">
            <label htmlFor="explore-search" className="b-eyebrow text-stone-400 block mb-1">
              Search routes, venues, and climbers
            </label>
            <div className="b-search-input-wrapper">
              <svg
                className="b-search-icon"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"
                />
              </svg>
              <input
                id="explore-search"
                type="search"
                placeholder="Search by route name, grade, crag, style, or climber..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full min-h-[44px]"
              />
            </div>
          </div>

          {searchQuery && (
            <button
              type="button"
              onClick={() => setSearchQuery('')}
              className="b-button b-button-ghost text-xs"
              aria-label="Clear search"
            >
              Clear
            </button>
          )}
        </div>

        {/* Concise Filter Pills */}
        <div className="b-filter-row" role="group" aria-label="Explore categories">
          <button
            type="button"
            aria-pressed={activeFilter === 'all'}
            onClick={() => setActiveFilter('all')}
            className="b-filter-pill"
            data-active={activeFilter === 'all' ? 'true' : undefined}
          >
            All Categories
          </button>
          <button
            type="button"
            aria-pressed={activeFilter === 'routes'}
            onClick={() => setActiveFilter('routes')}
            className="b-filter-pill"
            data-active={activeFilter === 'routes' ? 'true' : undefined}
          >
            Routes ({routes.length})
          </button>
          <button
            type="button"
            aria-pressed={activeFilter === 'venues'}
            onClick={() => setActiveFilter('venues')}
            className="b-filter-pill"
            data-active={activeFilter === 'venues' ? 'true' : undefined}
          >
            Crags & Gyms ({VENUES.length})
          </button>
          <button
            type="button"
            aria-pressed={activeFilter === 'climbers'}
            onClick={() => setActiveFilter('climbers')}
            className="b-filter-pill"
            data-active={activeFilter === 'climbers' ? 'true' : undefined}
          >
            Climbers ({climbers.length})
          </button>
        </div>

        {/* Search Results Summary */}
        <div className="text-xs text-stone-400 font-medium" role="status" aria-live="polite" aria-atomic="true">
          Showing {totalResults} result{totalResults !== 1 ? 's' : ''}
          {q ? ` matching "${searchQuery}"` : ''}
        </div>

        {/* Empty State */}
        {totalResults === 0 && (
          <div className="b-shelf text-center py-8">
            <p className="text-stone-300 font-medium">No results found for &ldquo;{searchQuery}&rdquo;</p>
            <p className="text-xs text-stone-400 mt-1 mb-3">
              Try searching for &quot;Redpoint&quot;, &quot;Limestone&quot;, &quot;Bishop&quot;, or &quot;Maya&quot;.
            </p>
            <button
              type="button"
              onClick={() => {
                setSearchQuery('');
                setActiveFilter('all');
              }}
              className="b-button b-button-ghost text-xs"
            >
              Reset Filters
            </button>
          </div>
        )}

        {/* Category: Routes */}
        {filteredRoutes.length > 0 && (
          <section className="b-stack" aria-labelledby="routes-list-title">
            <h2 id="routes-list-title" className="text-xs font-bold uppercase tracking-wider text-stone-400">
              Rock Climbing Routes ({filteredRoutes.length})
            </h2>

            <div className="b-stack">
              {filteredRoutes.map((r) => {
                const isSaved = savedRouteIds.includes(r.id);
                return (
                  <div key={r.id} className="b-shelf flex items-center justify-between flex-wrap gap-3">
                    <div>
                      <div className="b-eyebrow text-stone-400 mb-0.5">
                        {r.crag} · {r.type} · {r.height} · {r.rock}
                      </div>
                      <h3 className="text-lg font-semibold text-stone-100">
                        <span className="b-serif text-indigo-400 mr-2">{r.grade}</span>
                        <Link href={`/app/route/${r.id}`} className="b-serif hover:underline inline-flex items-center min-h-[44px]">
                          {r.name}
                        </Link>
                      </h3>
                      <p className="text-xs text-stone-400 mt-1 max-w-md">{r.description}</p>
                    </div>

                    <div className="b-inline">
                      <button
                        type="button"
                        onClick={() => toggleSave(r.id)}
                        className={`b-button text-xs ${isSaved ? 'b-button-primary' : 'b-button-ghost'}`}
                      >
                        {isSaved ? 'Saved' : 'Save'}
                      </button>
                      <Link href={`/app/route/${r.id}`} className="b-button b-button-ghost text-xs">
                        View Beta →
                      </Link>
                      <Link href={`/app/log?route=${r.id}`} className="b-button b-button-primary text-xs">
                        Log Attempt
                      </Link>
                    </div>
                  </div>
                );
              })}
            </div>
          </section>
        )}

        {/* Category: Venues (Crags & Gyms) */}
        {filteredVenues.length > 0 && (
          <section className="b-stack" aria-labelledby="venues-list-title">
            <h2 id="venues-list-title" className="text-xs font-bold uppercase tracking-wider text-stone-400">
              Crags & Climbing Gyms ({filteredVenues.length})
            </h2>

            <div className="b-stack">
              {filteredVenues.map((v) => (
                <div key={v.id} className="b-shelf flex items-start justify-between flex-wrap gap-3">
                  <div className="max-w-xl">
                    <div className="b-inline mb-1">
                      <span className="b-eyebrow text-stone-400">{v.location}</span>
                      <span className="text-stone-600" aria-hidden="true">•</span>
                      <span className="b-status text-xs">{v.type}</span>
                    </div>
                    <h3 className="text-lg font-bold text-stone-100">{v.name}</h3>
                    <p className="text-xs text-stone-300 font-mono mt-0.5">{v.routesCount}</p>
                    <p className="text-xs text-stone-400 mt-1.5 leading-relaxed">{v.description}</p>
                    <div className="text-xs text-stone-400 mt-1">
                      Surface: <strong className="text-stone-300">{v.rockOrWall}</strong>
                    </div>
                  </div>
                  {v.featuredRouteId && (
                    <div className="pt-2">
                      <Link href={`/app/route/${v.featuredRouteId}`} className="b-button b-button-ghost text-xs">
                        View Crag Testpiece →
                      </Link>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </section>
        )}

        {/* Category: Climbers */}
        {filteredClimbers.length > 0 && (
          <section className="b-stack" aria-labelledby="climbers-list-title">
            <h2 id="climbers-list-title" className="text-xs font-bold uppercase tracking-wider text-stone-400">
              Community Climbers ({filteredClimbers.length})
            </h2>

            <div className="b-stack">
              {filteredClimbers.map((c) => (
                <div key={c.id} className="b-shelf flex items-center justify-between flex-wrap gap-3">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-slate-800 border border-stone-700 flex items-center justify-center font-bold text-stone-200 text-sm">
                      {c.name.slice(0, 2)}
                    </div>
                    <div>
                      <Link href={c.href} className="font-semibold text-stone-100 hover:text-indigo-400 hover:underline inline-flex items-center min-h-[44px]">
                        {c.name}
                      </Link>
                      <div className="text-xs text-indigo-400 mt-0.5">{c.recentAscent}</div>
                    </div>
                  </div>

                  <Link href={c.href} className="b-button b-button-ghost text-xs">
                    View Profile →
                  </Link>
                </div>
              ))}
            </div>
          </section>
        )}
      </div>
    </article>
  );
}

/* ==========================================================================
   2. Activity Screen (/app/activity)
   ========================================================================== */

export function ActivityScreen() {
  // Selective subscription (F13).
  const {
    activityRead,
    markActivityRead,
    likedPostIds,
    followingMaya,
    comments,
    entries,
  } = useJournal(
    useShallow((s) => ({
      activityRead: s.activityRead,
      markActivityRead: s.markActivityRead,
      likedPostIds: s.likedPostIds,
      followingMaya: s.followingMaya,
      comments: s.comments,
      entries: s.entries,
    }))
  );
  const [readAnnouncement, setReadAnnouncement] = useState<string | null>(null);
  const [readError, setReadError] = useState<string | null>(null);

  const handleMarkAllRead = () => {
    setReadError(null);
    setReadAnnouncement(null);
    const res = markActivityRead();
    if ('error' in res) {
      setReadError(`Could not mark notifications as read: ${res.error}`);
    } else {
      setReadAnnouncement('All activity notifications marked as read.');
    }
  };
  const isLikedMaya = likedPostIds.includes('maya-redpoint');
  const recentSeedComments = comments.filter((c) => c.postId === 'maya-redpoint').slice(-3);

  return (
    <article className="b-page" aria-labelledby="activity-heading">
      <div className="b-page-header">
        <span className="b-eyebrow">Feed & Notifications</span>
        <Link href="/app" className="b-button b-button-ghost">
          Back to Feed
        </Link>
      </div>

      <div className="b-panel b-stack">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <div className="b-eyebrow text-stone-400 mb-1">Climbing Community</div>
            <h1 id="activity-heading" className="b-serif text-3xl font-semibold italic text-stone-100">
              Community Activity
            </h1>
            <p className="b-muted text-sm mt-1">
              Ascents, comments, partner cheers, and log updates from Stonegate and your crew.
            </p>
          </div>

          <button
            type="button"
            onClick={handleMarkAllRead}
            disabled={activityRead}
            className={`b-button ${activityRead ? 'b-button-ghost opacity-60' : 'b-button-primary'}`}
          >
            {activityRead ? 'All caught up' : 'Mark all as read'}
          </button>
        </div>

        {readError && (
          <div role="alert" className="p-3 bg-red-950/60 border border-red-500 rounded text-red-300 text-xs">
            {readError}
          </div>
        )}
        {readAnnouncement && (
          <div role="status" aria-live="polite" className="p-3 bg-emerald-950/60 border border-emerald-500 rounded text-emerald-300 text-xs">
            {readAnnouncement}
          </div>
        )}
        {/* Activity Items List */}
        <ul className="b-activity-list" role="list">
          {/* Item 1: Maya's Send */}
          <li className="b-activity-item" data-unread={!activityRead ? 'true' : undefined}>
            {!activityRead && <span className="b-unread-dot" aria-hidden="true" />}
            <div className="b-activity-icon">
              <svg className="w-5 h-5 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
              </svg>
            </div>
            <div className="b-activity-content">
              {!activityRead && <span className="text-xs font-semibold text-indigo-400">Unread</span>}
              <p className="b-activity-text">
                <Link href="/app/climber/maya" className="font-semibold text-stone-100 hover:underline inline-flex items-center min-h-[44px]">
                  Maya K.
                </Link>{' '}
                sent{' '}
                <Link href="/app/send/maya-redpoint" className="b-serif text-indigo-400 font-semibold hover:underline inline-flex items-center min-h-[44px]">
                  Redpoint Ridge (5.12a)
                </Link>{' '}
              </p>
              <div className="b-activity-meta">Sep 6, 2026 · 09:00 UTC · Verified Clean Send</div>
              <div className="pt-1">
                <Link href="/app/send/maya-redpoint" className="b-button b-button-ghost text-xs">
                  Inspect Climb Report →
                </Link>
              </div>
            </div>
          </li>

          {/* Item 2: User's Cheer on Maya's Send (if liked) */}
          {isLikedMaya && (
            <li className="b-activity-item">
              <div className="b-activity-icon">
                <svg className="w-5 h-5 text-red-400" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="m11.645 20.91-.007-.003-.022-.012a15.247 15.247 0 0 1-.383-.218 25.18 25.18 0 0 1-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0 1 12 5.052 5.5 5.5 0 0 1 16.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 0 1-4.244 3.17 15.247 15.247 0 0 1-.383.219l-.022.012-.007.004-.003.001a.752.752 0 0 1-.704 0l-.003-.001Z" />
                </svg>
              </div>
              <div className="b-activity-content">
                <p className="b-activity-text">
                  You cheered <strong>Maya K.&apos;s</strong> send on Redpoint Ridge.
                </p>
                <div className="b-activity-meta">Today · Partner Support</div>
              </div>
            </li>
          )}

          {/* Item 3: Comments on Maya's Send */}
          {recentSeedComments.map((c) => (
            <li key={c.id} className="b-activity-item">
              <div className="b-activity-icon">
                <svg className="w-5 h-5 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 8.25h9m-9 3H12m-9.75 1.51c0 1.6 1.123 2.994 2.707 3.227 1.129.166 2.27.293 3.423.379.35.026.67.21.865.501L12 21l2.755-4.133a1.14 1.14 0 0 1 .865-.502 48.177 48.177 0 0 0 3.423-.379c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0 0 12 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018Z" />
                </svg>
              </div>
              <div className="b-activity-content">
                <p className="b-activity-text">
                  <strong>{c.author}</strong> commented on Maya K.&apos;s send: &ldquo;{c.text}&rdquo;
                </p>
                <div className="b-activity-meta">
                  {c.createdAt?.split('T')[0] || 'Sep 6, 2026'} ·{' '}
                  <Link href="/app/send/maya-redpoint#comments" className="text-indigo-400 hover:underline inline-flex items-center min-h-[44px]">
                    View discussion
                  </Link>
                </div>
              </div>
            </li>
          ))}

          {/* Item 4: Following Maya Status */}
          <li className="b-activity-item">
            <div className="b-activity-icon">
              <svg className="w-5 h-5 text-stone-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z" />
              </svg>
            </div>
            <div className="b-activity-content">
              <p className="b-activity-text">
                You are {followingMaya ? 'following' : 'not following'} <strong>Maya K.</strong> for crag ascents.
              </p>
              <div className="b-activity-meta">Stonegate Partner Network</div>
            </div>
          </li>

          {/* Item 5: User's own logged sessions */}
          {entries.map((e) => (
            <li key={e.id} className="b-activity-item">
              <div className="b-activity-icon">
                <svg className="w-5 h-5 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
              </div>
              <div className="b-activity-content">
                <p className="b-activity-text">
                  You logged {e.attempts} attempts on{' '}
                  <Link href={`/app/route/${e.routeId}`} className="b-serif font-semibold text-indigo-400 hover:underline inline-flex items-center min-h-[44px]">
                    {routes.find((r) => r.id === e.routeId)?.name || e.routeId}
                  </Link>
                </p>
                <div className="b-activity-meta">
                  <Link href={`/app/attempt/${e.id}`} className="text-indigo-400 hover:underline inline-flex items-center min-h-[44px]">
                    View attempt
                  </Link>
                </div>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </article>
  );
}

/* ==========================================================================
   3. Climber Profile Screen (/app/climber/[id])
   ========================================================================== */

export interface ClimberProfileProps {
  climberId: string;
}

export function ClimberProfile({ climberId }: ClimberProfileProps) {
  // Selective subscription (F13).
  const { followingMaya, setFollowing } = useJournal(
    useShallow((s) => ({ followingMaya: s.followingMaya, setFollowing: s.setFollowing }))
  );
  const isMaya = climberId === 'maya' || climberId === 'maya-k';
  const isAlex = climberId === 'alex';

  if (!isMaya && !isAlex) {
    return (
      <div className="b-page" role="region" aria-labelledby="climber-not-found-heading">
        <div className="b-page-header">
          <Link href="/app/explore" className="b-button b-button-ghost">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
              <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
            </svg>
            Back to Explore
          </Link>
          <span className="b-eyebrow">Climber Not Found</span>
        </div>
        <div className="b-panel b-stack">
          <h1 id="climber-not-found-heading" className="b-serif text-2xl font-bold">
            Climber profile not found
          </h1>
          <p className="b-muted">
            The climber profile with identifier &quot;{climberId}&quot; does not exist in the local climbing directory.
          </p>
          <div className="b-inline">
            <Link href="/app/explore" className="b-button b-button-primary">
              Browse Community Directory
            </Link>
            <Link href="/app/climber/maya" className="b-button">
              View Maya K.
            </Link>
            <Link href="/app" className="b-button b-button-ghost">
              Return to Feed
            </Link>
          </div>
        </div>
      </div>
    );
  }

  if (isAlex) {
    return (
      <article className="b-page" aria-labelledby="climber-alex-title">
        <div className="b-page-header">
          <Link href="/app/explore" className="b-button b-button-ghost">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
              <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
            </svg>
            Back to Explore
          </Link>
          <span className="b-eyebrow">Your Climber Profile</span>
        </div>
        <div className="b-panel b-stack">
          <div className="flex items-start justify-between flex-wrap gap-4">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 rounded-full bg-slate-800 border-2 border-indigo-500/50 flex items-center justify-center font-bold text-xl text-stone-100">
                AR
              </div>
              <div>
                <h1 id="climber-alex-title" className="text-2xl font-bold text-stone-100">
                  Alex R. (You)
                </h1>
                <p className="text-xs text-stone-400 mt-0.5">
                  Local Journal Climber · Home Crag: Stonegate
                </p>
              </div>
            </div>
            <Link href="/app/profile" className="b-button b-button-primary">
              Open Full Journal &amp; Profile →
            </Link>
          </div>
          <p className="b-muted text-sm">
            This is your active journal profile. You can inspect your sessions, saved routes, and logbook in your profile view.
          </p>
        </div>
      </article>
    );
  }

  return (
    <article className="b-page" aria-labelledby="climber-title">
      <div className="b-page-header">
        <Link href="/app/explore" className="b-button b-button-ghost">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
            <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
          </svg>
          Back to Explore
        </Link>
        <span className="b-eyebrow">Climber Dossier</span>
      </div>

      <div className="b-panel b-stack">
        <div className="flex items-start justify-between flex-wrap gap-4">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-full bg-slate-800 border-2 border-indigo-500/50 flex items-center justify-center font-bold text-xl text-stone-100">
              MK
            </div>
            <div>
              <h1 id="climber-title" className="text-2xl font-bold text-stone-100">
                Maya K.
              </h1>
              <p className="text-xs text-stone-400 mt-0.5">
                Stonegate Local · 5.12 Sport Climber
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={() => setFollowing(!followingMaya)}
            aria-pressed={followingMaya}
            className={`b-button ${followingMaya ? 'b-button-ghost' : 'b-button-primary'}`}
          >
            {followingMaya ? 'Following Maya' : '+ Follow Maya'}
          </button>
        </div>

        <div className="b-shelf">
          <h2 className="text-xs font-bold uppercase tracking-wider text-stone-400 mb-2">
            Bio & Background
          </h2>
          <p className="text-sm text-stone-300 leading-relaxed m-0">
            Projecting steep limestone in the canyon. Passionate about deliberate footwork, quiet climbing, and long endurance links. Redpointed 5.12a at Stonegate this season.
          </p>
        </div>

        {/* Featured Ascent */}
        <div className="b-shelf b-stack">
          <span className="text-xs font-bold uppercase tracking-wider text-stone-400">
            Featured Recent Ascent
          </span>
          <div className="flex items-start justify-between flex-wrap gap-2">
            <div>
              <h3 className="text-lg font-semibold text-stone-100">
                <span className="b-serif text-indigo-400 mr-2">5.12a</span>
                <Link href="/app/route/redpoint-ridge" className="b-serif hover:underline inline-flex items-center min-h-[44px]">
                  Redpoint Ridge
                </Link>
              </h3>
              <p className="text-xs text-stone-400 mt-0.5">
                Stonegate · Sport · 27 m · 6 attempts · Clean Send
              </p>
            </div>

            <Link href="/app/send/maya-redpoint" className="b-button b-button-primary text-xs">
              View Send Report →
            </Link>
          </div>
        </div>

        <div className="b-inline pt-2 border-t border-stone-800">
          <Link href="/app" className="b-button b-button-ghost">
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
