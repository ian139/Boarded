'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useJournal } from '@/lib/boarded/store';
import { mayaPost, routes, type Entry } from '@/lib/boarded/journal';
import { Photo } from './Photo';

function SentBadge() {
  return (
    <div className="b-status b-status-sent" aria-label="Outcome: Sent">
      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3} aria-hidden="true">
        <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
      </svg>
      <span>Sent</span>
    </div>
  );
}

function AttemptBadge() {
  return (
    <div className="b-status b-status-attempt" aria-label="Outcome: Attempted">
      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5} aria-hidden="true">
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
      </svg>
      <span>Attempted</span>
    </div>
  );
}

export function Feed() {
  const {
    entries,
    savedRouteIds,
    likedPostIds,
    comments,
    followingMaya,
    ready,
    error,
    retryStorage,
    toggleLike,
    toggleSave,
  } = useJournal();

  const [announcement, setAnnouncement] = useState<string>('');

  if (!ready) {
    return (
      <div className="w-full max-w-6xl mx-auto flex flex-col lg:flex-row items-start gap-8" aria-busy="true">
        <div className="b-page flex-1">
          <header className="b-page-header">
            <div>
              <h1 className="text-2xl font-bold tracking-tight text-[#F4F2EB]">Feed</h1>
              <p className="b-muted text-xs mt-0.5">Dispatches from Stonegate &amp; the crag</p>
            </div>
            <span className="b-eyebrow">Autumn Season 2026</span>
          </header>
          <div className="b-panel text-center py-16">
            <div className="inline-block animate-pulse text-stone-300 text-sm font-medium mb-2">
              Loading climbing journal...
            </div>
            <p className="b-muted text-xs">Retrieving local ascents and community beta</p>
          </div>
        </div>
      </div>
    );
  }

  if (error && entries.length === 0) {
    return (
      <div className="w-full max-w-6xl mx-auto flex flex-col lg:flex-row items-start gap-8">
        <div className="b-page flex-1">
          <header className="b-page-header">
            <div>
              <h1 className="text-2xl font-bold tracking-tight text-[#F4F2EB]">Feed</h1>
              <p className="b-muted text-xs mt-0.5">Dispatches from Stonegate &amp; the crag</p>
            </div>
            <span className="b-eyebrow">Autumn Season 2026</span>
          </header>
          <div className="b-panel text-center py-12">
            <h2 className="text-lg font-semibold text-[#FF5C5C] mb-2">Storage unavailable</h2>
            <p className="b-muted text-sm mb-6">{error}</p>
            <button
              type="button"
              onClick={retryStorage}
              className="b-button b-button-primary mx-auto"
            >
              Retry journal storage
            </button>
          </div>
        </div>
      </div>
    );
  }

  const publishedUserEntries = entries.filter((e) => e.published);
  const showMayaPost = followingMaya;
  const isFeedEmpty = !showMayaPost && publishedUserEntries.length === 0;

  const isMayaLiked = likedPostIds.includes(mayaPost.id);
  const mayaKudosCount = mayaPost.baseKudos + (isMayaLiked ? 1 : 0);
  const mayaPostComments = comments.filter((c) => c.postId === mayaPost.id);
  const mayaTotalComments = mayaPostComments.length;
  const isMayaRouteSaved = savedRouteIds.includes(mayaPost.routeId);
  const mayaRoute = routes.find((r) => r.id === mayaPost.routeId);
  const nextProjectRoute = routes.find((r) => r.id === 'golden-hour') || routes[2] || routes[0];

  const handleToggleLikeMaya = () => {
    const res = toggleLike(mayaPost.id);
    if ('ok' in res) {
      setAnnouncement(isMayaLiked ? 'Cheer removed' : 'Cheered Maya’s redpoint send!');
    }
  };

  const handleToggleSaveMaya = () => {
    const res = toggleSave(mayaPost.routeId);
    if ('ok' in res) {
      setAnnouncement(isMayaRouteSaved ? 'Route removed from saved list' : 'Redpoint Ridge saved to your routes');
    }
  };

  return (
    <div className="w-full max-w-6xl mx-auto flex flex-col lg:flex-row items-start gap-8">
      {/* Screen Reader Live Announcement */}
      <div className="sr-only" role="status" aria-live="polite">
        {announcement}
      </div>

      {/* Primary Central Column */}
      <div className="b-page flex-1">
        {/* Page Header */}
        <header className="b-page-header">
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-[#F4F2EB]">Feed</h1>
            <p className="b-muted text-xs mt-0.5">Dispatches from Stonegate &amp; the crag</p>
          </div>
          <span className="b-eyebrow">Autumn Season 2026</span>
        </header>

        {/* Empty State */}
        {isFeedEmpty ? (
          <div className="b-panel text-center py-16">
            <div className="w-12 h-12 rounded-full bg-[rgba(244,242,235,0.06)] border border-[rgba(244,242,235,0.14)] flex items-center justify-center mx-auto mb-4 text-stone-400">
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5} aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
              </svg>
            </div>
            <h2 className="text-lg font-semibold text-[#F4F2EB] mb-2">Your feed is quiet</h2>
            <p className="b-muted text-sm max-w-md mx-auto mb-6">
              You are not following any climbers yet and have not published any ascents to your local journal.
            </p>
            <Link href="/app/explore" className="b-button b-button-primary mx-auto">
              Explore Climbs &amp; Community
            </Link>
          </div>
        ) : (
          <div className="b-stack gap-6">
            {/* Maya K. Redpoint Ridge Send Card */}
            {showMayaPost && (
              <article className="b-panel" aria-labelledby="post-maya-heading">
                {/* Climber & Post Meta Header */}
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <div className="w-10 h-10 min-w-[2.5rem] rounded-full bg-stone-800 border border-[rgba(244,242,235,0.18)] flex items-center justify-center text-sm font-semibold text-[#F4F2EB] flex-shrink-0 whitespace-nowrap">
                      MK
                    </div>
                    <div className="min-w-0 flex-1">
                      <Link
                        href="/app/send/maya-redpoint"
                        className="font-semibold text-sm text-[#F4F2EB] hover:underline focus:underline inline-flex items-center min-h-[44px]"
                      >
                        {mayaPost.author}
                      </Link>
                      <div className="b-tertiary text-xs">
                        <time dateTime={mayaPost.timestamp}>{mayaPost.displayTime}</time> · {mayaPost.crag}
                      </div>
                    </div>
                  </div>

                  {/* Sent Badge (Send Green strictly reserved for sends) */}
                  <div className="flex-shrink-0">
                    <SentBadge />
                  </div>
                </div>

                {/* Hero Outdoor Limestone Photograph */}
                <Link
                  href="/app/send/maya-redpoint"
                  className="block focus-visible:rounded-xl overflow-hidden group"
                  aria-label="View full send report for Redpoint Ridge 5.12a"
                >
                  <Photo
                    src={mayaPost.photoUrl || '/boarded/redpoint-ridge.webp'}
                    alt="Maya K. clipping quickdraw on Redpoint Ridge 5.12a limestone overhang at Stonegate"
                    className="group-hover:opacity-95 transition-opacity"
                  />
                </Link>

                {/* Route Grade & Editorial Headline */}
                <div className="flex flex-col gap-2">
                  <div className="flex items-baseline gap-3 sm:gap-4 flex-wrap">
                    <span className="b-grade-hero" aria-label={`Grade ${mayaPost.grade}`}>
                      {mayaPost.grade}
                    </span>
                    <h2 className="b-serif text-2xl sm:text-3xl md:text-4xl text-[#F4F2EB] font-normal m-0 inline">
                      <Link
                        href="/app/route/redpoint-ridge"
                        id="post-maya-heading"
                        className="hover:text-[#345CFF] focus-visible:text-[#345CFF] transition-colors inline-block min-h-[44px] py-1"
                      >
                        {mayaPost.routeName}
                      </Link>
                    </h2>
                  </div>

                  {/* Route Technical Specifications */}
                  <div className="b-facts">
                    <span className="b-fact-item">
                      <span className="b-eyebrow text-stone-300">
                        {mayaRoute
                          ? `${mayaRoute.type} · ${mayaRoute.height} · ${mayaRoute.rock} · ${mayaRoute.style}`
                          : `${mayaPost.type} · ${mayaPost.height} · ${mayaPost.rock} · ${mayaPost.style}`}
                      </span>
                    </span>
                    <span aria-hidden="true" className="text-stone-400">·</span>
                    <span className="b-fact-item text-xs text-stone-300">
                      <strong className="text-[#F4F2EB]">{mayaPost.attempts}</strong> attempts to redpoint
                    </span>
                  </div>
                </div>

                {/* Reflection Caption */}
                <blockquote className="border-l-2 border-[rgba(244,242,235,0.18)] pl-3 text-stone-300 text-sm italic">
                  &ldquo;{mayaPost.caption}&rdquo;
                </blockquote>

                {/* Feed Interactive Actions: Cheer, Comment, Save, Share */}
                <footer className="pt-2 border-t border-[rgba(244,242,235,0.08)] flex items-center justify-between flex-wrap gap-2">
                  <div className="flex items-center gap-2 flex-wrap">
                    {/* Cheer Button */}
                    <button
                      type="button"
                      onClick={handleToggleLikeMaya}
                      aria-pressed={isMayaLiked}
                      data-active={isMayaLiked}
                      className="b-action-chip"
                    >
                      <svg className={`w-4 h-4 ${isMayaLiked ? 'text-[#345CFF]' : ''}`} fill={isMayaLiked ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.75} aria-hidden="true">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
                      </svg>
                      <span>Cheer ({mayaKudosCount})</span>
                    </button>

                    {/* Comment Link */}
                    <Link
                      href="/app/send/maya-redpoint#comments"
                      className="b-action-chip"
                    >
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.75} aria-hidden="true">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.48.432.447.74 1.04.586 1.641a4.483 4.483 0 0 1-.923 1.785A5.969 5.969 0 0 0 6 21c1.282 0 2.47-.402 3.445-1.087.81.22 1.668.337 2.555.337Z" />
                      </svg>
                      <span>Comment ({mayaTotalComments})</span>
                    </Link>
                  </div>

                  <div className="flex items-center gap-2">
                    {/* Save Route Link */}
                    <button
                      type="button"
                      onClick={handleToggleSaveMaya}
                      aria-pressed={isMayaRouteSaved}
                      data-active={isMayaRouteSaved}
                      className="b-action-chip"
                      title={isMayaRouteSaved ? 'Route saved' : 'Save route to wishlist'}
                    >
                      <svg className={`w-4 h-4 ${isMayaRouteSaved ? 'text-[#345CFF]' : ''}`} fill={isMayaRouteSaved ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.75} aria-hidden="true">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0 1 11.186 0Z" />
                      </svg>
                      <span>{isMayaRouteSaved ? 'Saved' : 'Save'}</span>
                    </button>

                    {/* Share Friend Link */}
                    <Link
                      href="/app/send/maya-redpoint#share"
                      className="b-action-chip"
                      title="Share send with a climbing partner"
                    >
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.75} aria-hidden="true">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z" />
                      </svg>
                      <span>Share</span>
                    </Link>
                  </div>
                </footer>
              </article>
            )}

            {/* Published User Entries */}
            {publishedUserEntries.map((entry: Entry) => {
              const route = routes.find((r) => r.id === entry.routeId);
              const isLiked = likedPostIds.includes(entry.id);
              const isSaved = route ? savedRouteIds.includes(route.id) : false;

              return (
                <article key={entry.id} className="b-panel" aria-labelledby={`entry-${entry.id}-heading`}>
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-3 min-w-0 flex-1">
                      <div className="w-10 h-10 min-w-[2.5rem] rounded-full bg-[#1F232D] border border-[rgba(244,242,235,0.18)] flex items-center justify-center text-sm font-semibold text-[#F4F2EB] flex-shrink-0 whitespace-nowrap">
                        AR
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="font-semibold text-sm text-[#F4F2EB]">
                          Alex R. <span className="b-tertiary text-xs font-normal">(You)</span>
                        </div>
                        <div className="b-tertiary text-xs">
                          <time dateTime={entry.date}>{entry.date}</time> · {route?.crag || 'Local Crag'}
                        </div>
                      </div>
                    </div>

                    <div className="flex-shrink-0">
                      {entry.outcome === 'sent' ? (
                        <SentBadge />
                      ) : (
                        <AttemptBadge />
                      )}
                    </div>
                  </div>

                  <div className="flex flex-col gap-2">
                    <div className="flex items-baseline gap-3 sm:gap-4 flex-wrap">
                      <span className="b-grade-hero" aria-label={`Grade ${route?.grade || '5.10'}`}>
                        {route?.grade || '5.10'}
                      </span>
                      <h2 className="b-serif text-2xl sm:text-3xl text-[#F4F2EB] font-normal m-0 inline">
                        <Link
                          href={route ? `/app/route/${route.id}` : '#'}
                          id={`entry-${entry.id}-heading`}
                          className="hover:text-[#345CFF] focus-visible:text-[#345CFF] transition-colors inline-block min-h-[44px] py-1"
                        >
                          {route?.name || 'Climbing Route'}
                        </Link>
                      </h2>
                    </div>

                    <div className="b-facts">
                      {route && (
                        <>
                          <span className="b-fact-item">
                            <span className="b-eyebrow text-stone-300">
                              {route.type} · {route.height} · {route.rock} · {route.style}
                            </span>
                          </span>
                          <span aria-hidden="true" className="text-stone-400">·</span>
                        </>
                      )}
                      <span className="b-fact-item text-xs text-stone-300">
                        <strong className="text-[#F4F2EB]">{entry.attempts}</strong> {entry.attempts === 1 ? 'try' : 'tries'} logged
                      </span>
                      {entry.conditions && (
                        <>
                          <span aria-hidden="true" className="text-stone-400">·</span>
                          <span className="b-fact-item text-xs text-stone-300">
                            Conditions: {entry.conditions}
                          </span>
                        </>
                      )}
                    </div>
                  </div>

                  {entry.caption && (
                    <p className="text-stone-300 text-sm">{entry.caption}</p>
                  )}

                  {entry.notes && (
                    <p className="b-muted text-xs italic bg-stone-900/60 p-2.5 rounded-lg border border-[rgba(244,242,235,0.06)]">
                      Beta notes: {entry.notes}
                    </p>
                  )}

                  <footer className="pt-2 border-t border-[rgba(244,242,235,0.08)] flex items-center justify-between flex-wrap gap-2">
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => toggleLike(entry.id)}
                        aria-pressed={isLiked}
                        data-active={isLiked}
                        className="b-action-chip"
                      >
                        <svg className={`w-4 h-4 ${isLiked ? 'text-[#345CFF]' : ''}`} fill={isLiked ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.75} aria-hidden="true">
                          <path strokeLinecap="round" strokeLinejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
                        </svg>
                        <span>Cheer ({isLiked ? 1 : 0})</span>
                      </button>
                    </div>

                    <div className="flex items-center gap-2">
                      {route && (
                        <button
                          type="button"
                          onClick={() => toggleSave(route.id)}
                          aria-pressed={isSaved}
                          data-active={isSaved}
                          className="b-action-chip"
                        >
                          <svg className={`w-4 h-4 ${isSaved ? 'text-[#345CFF]' : ''}`} fill={isSaved ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.75} aria-hidden="true">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0 1 11.186 0Z" />
                          </svg>
                          <span>{isSaved ? 'Saved' : 'Save'}</span>
                        </button>
                      )}
                    </div>
                  </footer>
                </article>
              );
            })}
          </div>
        )}
      </div>

      {/* Sparse Right Route/Crag Context on Desktop (1440x1024) */}
      <aside className="hidden xl:flex flex-col gap-6 w-80 flex-shrink-0" aria-label="Crag context &amp; upcoming routes">
        {/* Featured Crag Panel */}
        <div className="b-panel">
          <span className="b-eyebrow">Featured Crag</span>
          <h2 className="b-serif text-2xl text-[#F4F2EB]">Stonegate</h2>
          <p className="b-muted text-xs leading-relaxed">
            Pocketed limestone canyon with vertical to gently overhanging sport routes. High friction in cool autumn morning conditions.
          </p>

          <div className="pt-3 border-t border-[rgba(244,242,235,0.08)] b-stack gap-2">
            <div className="flex justify-between text-xs">
              <span className="b-muted">Rock type</span>
              <span className="text-[#F4F2EB] font-medium">Limestone</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="b-muted">Conditions</span>
              <span className="text-[#F4F2EB] font-medium">Crisp · 18°C</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="b-muted">Approach</span>
              <span className="text-[#F4F2EB] font-medium">15 min trail</span>
            </div>
          </div>

          <Link
            href="/app/route/redpoint-ridge"
            className="b-button text-xs justify-center mt-2 w-full"
          >
            View Redpoint Ridge Topo
          </Link>
        </div>

        {/* Actionable Next Route Project Hint */}
        <div className="b-panel">
          <span className="b-eyebrow">Next Route Project</span>
          <div className="flex items-baseline gap-3 mt-1">
            <span className="b-grade-hero text-4xl sm:text-5xl" aria-label={`Grade ${nextProjectRoute.grade}`}>
              {nextProjectRoute.grade}
            </span>
            <h2 className="b-serif text-2xl text-[#F4F2EB] font-normal m-0 inline">
              <Link
                href={`/app/route/${nextProjectRoute.id}`}
                className="hover:text-[#345CFF] focus-visible:text-[#345CFF] transition-colors inline-block min-h-[44px] py-1"
              >
                {nextProjectRoute.name}
              </Link>
            </h2>
          </div>
          <div className="b-facts mt-1">
            <span className="b-eyebrow text-stone-300">
              {nextProjectRoute.crag} · {nextProjectRoute.type} · {nextProjectRoute.height} · {nextProjectRoute.rock} · {nextProjectRoute.style}
            </span>
          </div>
          <p className="b-muted text-xs leading-relaxed mt-2">
            {nextProjectRoute.description}
          </p>

          <div className="pt-3 border-t border-[rgba(244,242,235,0.08)] flex flex-col gap-2">
            <Link
              href={`/app/route/${nextProjectRoute.id}`}
              className="b-button text-xs justify-center w-full"
            >
              Inspect Route &amp; Beta
            </Link>
            <Link
              href={`/app/log`}
              className="b-button b-button-primary text-xs justify-center w-full"
            >
              Record Crag Session
            </Link>
          </div>
        </div>
      </aside>
    </div>
  );
}
