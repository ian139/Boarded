'use client';

import { useState, useRef } from 'react';
import Link from 'next/link';
import { Photo } from '@/components/boarded/Photo';
import {
  routes,
  mayaPost,
} from '@/lib/boarded/journal';
import { useJournal } from '@/lib/boarded/store';

/* ==========================================================================
   Shared Reusable Icons
   ========================================================================== */

function ArrowLeftIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
      <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
    </svg>
  );
}

function CheckmarkIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5} aria-hidden="true">
      <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
    </svg>
  );
}

function BookmarkIcon({ active, className = 'w-4 h-4' }: { active: boolean; className?: string }) {
  return (
    <svg
      className={className}
      fill={active ? 'currentColor' : 'none'}
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={active ? 0 : 2}
      aria-hidden="true"
    >
      <path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0 1 11.186 0Z" />
    </svg>
  );
}

function HeartIcon({ active, className = 'w-4 h-4' }: { active: boolean; className?: string }) {
  return (
    <svg
      className={className}
      fill={active ? 'currentColor' : 'none'}
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={active ? 0 : 2}
      aria-hidden="true"
    >
      <path strokeLinecap="round" strokeLinejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
    </svg>
  );
}

function ChatBubbleIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
      <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 8.25h9m-9 3H12m-9.75 1.51c0 1.6 1.123 2.994 2.707 3.227 1.129.166 2.27.293 3.423.379.35.026.67.21.865.501L12 21l2.755-4.133a1.14 1.14 0 0 1 .865-.502 48.177 48.177 0 0 0 3.423-.379c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0 0 12 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018Z" />
    </svg>
  );
}

function ShareNodesIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
      <path strokeLinecap="round" strokeLinejoin="round" d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z" />
    </svg>
  );
}

function CopyDocIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
      <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 0 1-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 0 1 1.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 0 0-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375-9-9" />
    </svg>
  );
}

function PlusSymbolIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5} aria-hidden="true">
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
    </svg>
  );
}

/* ==========================================================================
   1. Send Detail Component (/app/send/[id])
   ========================================================================== */

export interface SendDetailProps {
  postId: string;
}

export function SendDetail({ postId }: SendDetailProps) {
  const {
    likedPostIds,
    toggleLike,
    savedRouteIds,
    toggleSave,
    comments,
    addComment,
    followingMaya,
    setFollowing,
    entries,
    ready,
  } = useJournal();

  const isMaya = postId === 'maya-redpoint';
  const userEntry = !isMaya ? entries.find((e) => e.id === postId) : null;

  const routeId = isMaya
    ? mayaPost.routeId
    : userEntry
    ? userEntry.routeId
    : '';
  const route = routes.find((r) => r.id === routeId);

  const postComments = comments.filter((c) => c.postId === postId);
  const [commentText, setCommentText] = useState('');
  const [commentError, setCommentError] = useState<string | null>(null);
  const [commentStatus, setCommentStatus] = useState<string | null>(null);

  const [copySuccess, setCopySuccess] = useState<string | null>(null);
  const [copyError, setCopyError] = useState<string | null>(null);
  const [manualCopyUrl, setManualCopyUrl] = useState<string | null>(null);

  const commentInputRef = useRef<HTMLTextAreaElement>(null);


  if (!ready && !isMaya && !userEntry) {
    return (
      <div className="b-page" aria-busy="true">
        <div className="b-panel text-center py-16">
          <div className="inline-block animate-pulse text-stone-300 text-sm font-medium mb-2">
            Loading climbing journal...
          </div>
          <p className="b-muted text-xs">Retrieving send report</p>
        </div>
      </div>
    );
  }

  if (!isMaya && !userEntry) {
    return (
      <div className="b-page" role="region" aria-labelledby="not-found-heading">
        <div className="b-page-header">
          <Link href="/app" className="b-button b-button-ghost">
            <ArrowLeftIcon />
            Back to Feed
          </Link>
          <span className="b-eyebrow">Climb Not Found</span>
        </div>
        <div className="b-panel b-stack">
          <h1 id="not-found-heading" className="b-serif text-2xl font-bold">
            Send report not found
          </h1>
          <p className="b-muted">
            The climb report you requested does not exist or has been removed from this local journal.
          </p>
          <div className="b-inline">
            <Link href="/app" className="b-button b-button-primary">
              Return to Feed
            </Link>
            <Link href="/app/explore" className="b-button">
              Explore Routes
            </Link>
          </div>
        </div>
      </div>
    );
  }

  // Enforce invariant: Only verified sent entries can display a send report
  if (userEntry && userEntry.outcome !== 'sent') {
    return (
      <article className="b-page" aria-labelledby="unsent-title">
        <div className="b-page-header">
          <Link href="/app" className="b-button b-button-ghost">
            <ArrowLeftIcon />
            Back to Feed
          </Link>
          <span className="b-eyebrow">Attempt In Progress</span>
        </div>
        <div className="b-panel b-stack">
          <div className="b-inline">
            <span className="b-status b-status-attempt">Attempted / Incomplete</span>
            <span className="b-eyebrow">Not a Verified Send</span>
          </div>
          <h1 id="unsent-title" className="b-serif text-2xl sm:text-3xl font-semibold italic text-stone-100">
            Send report unavailable
          </h1>
          <p className="b-muted">
            This climb for {route ? route.name : userEntry.routeId} is recorded as an in-progress attempt ({userEntry.attempts} {userEntry.attempts === 1 ? 'try' : 'tries'}), not a verified send. Send reports are only available for completed clean sends.
          </p>
          <div className="b-shelf b-stack">
            <div className="b-facts">
              <span className="b-fact-item">
                <strong className="text-stone-300">Date:</strong> {userEntry.date}
              </span>
              <span className="text-stone-600" aria-hidden="true">•</span>
              <span className="b-fact-item">
                <strong className="text-stone-300">Attempts:</strong> {userEntry.attempts}
              </span>
              {route && (
                <>
                  <span className="text-stone-600" aria-hidden="true">•</span>
                  <span className="b-fact-item">
                    <strong className="text-stone-300">Grade:</strong> {route.grade}
                  </span>
                </>
              )}
            </div>
            {userEntry.notes && (
              <p className="text-xs text-stone-300 italic m-0">&ldquo;{userEntry.notes}&rdquo;</p>
            )}
          </div>
          <div className="b-inline pt-2 border-t border-stone-800">
            <Link href={`/app/attempt/${userEntry.id}`} className="b-button b-button-primary">
              View Attempt Log &amp; Beta →
            </Link>
            <Link href="/app/profile" className="b-button">
              View Journal
            </Link>
            <Link href="/app" className="b-button b-button-ghost">
              Return to Feed
            </Link>
          </div>
        </div>
      </article>
    );
  }

  // Enforce invariant: Only published sent entries have public send detail
  if (userEntry && !userEntry.published) {
    return (
      <article className="b-page" aria-labelledby="unpublished-title">
        <div className="b-page-header">
          <Link href="/app" className="b-button b-button-ghost">
            <ArrowLeftIcon />
            Back to Feed
          </Link>
          <span className="b-eyebrow">Private Send</span>
        </div>
        <div className="b-panel b-stack">
          <div className="b-inline">
            <span className="b-status b-status-sent">
              <CheckmarkIcon className="w-3.5 h-3.5" />
              Verified Send
            </span>
            <span className="b-status">Private / Unpublished</span>
          </div>
          <h1 id="unpublished-title" className="b-serif text-2xl sm:text-3xl font-semibold italic text-stone-100">
            Send report not yet published
          </h1>
          <p className="b-muted">
            You recorded a clean send on {route ? route.name : userEntry.routeId} in {userEntry.attempts} {userEntry.attempts === 1 ? 'try' : 'tries'} on {userEntry.date}! However, this send report has not yet been published to the community feed.
          </p>
          <div className="b-shelf b-stack">
            <div className="b-facts">
              <span className="b-fact-item">
                <strong className="text-stone-300">Climber:</strong> Alex R.
              </span>
              <span className="text-stone-600" aria-hidden="true">•</span>
              <span className="b-fact-item">
                <strong className="text-stone-300">Attempts:</strong> {userEntry.attempts}
              </span>
              <span className="text-stone-600" aria-hidden="true">•</span>
              <span className="b-fact-item">
                <strong className="text-stone-300">Date:</strong> {userEntry.date}
              </span>
            </div>
            {userEntry.notes && (
              <p className="text-xs text-stone-300 italic m-0">&ldquo;{userEntry.notes}&rdquo;</p>
            )}
          </div>
          <div className="b-inline pt-2 border-t border-stone-800">
            <Link href={`/app/share/${userEntry.id}`} className="b-button b-button-primary">
              Publish Send Card →
            </Link>
            <Link href={`/app/attempt/${userEntry.id}`} className="b-button">
              View Attempt Record
            </Link>
            <Link href="/app" className="b-button b-button-ghost">
              Return to Feed
            </Link>
          </div>
        </div>
      </article>
    );
  }

  const authorName = isMaya ? mayaPost.author : 'Alex R.';
  const displayDate = isMaya ? mayaPost.displayTime : userEntry?.date;
  const attemptsCount = isMaya ? mayaPost.attempts : userEntry?.attempts;
  const caption = isMaya ? mayaPost.caption : (userEntry?.caption ?? '');
  const isLiked = likedPostIds.includes(postId);
  const isSaved = route ? savedRouteIds.includes(route.id) : false;
  const cheersCount = isMaya
    ? mayaPost.baseKudos + (isLiked ? 1 : 0)
    : isLiked
    ? 1
    : 0;

  const handleToggleLike = () => {
    toggleLike(postId);
  };

  const handleToggleSave = () => {
    if (route) {
      toggleSave(route.id);
    }
  };

  const handleAddComment = (e: React.FormEvent) => {
    e.preventDefault();
    const clean = commentText.trim();
    if (!clean) {
      setCommentError('Comment text cannot be empty.');
      setCommentStatus(null);
      return;
    }
    if (clean.length > 500) {
      setCommentError('Comment cannot exceed 500 characters.');
      setCommentStatus(null);
      return;
    }

    const res = addComment(postId, clean);
    if ('error' in res) {
      setCommentError(res.error);
      setCommentStatus(null);
    } else {
      setCommentText('');
      setCommentError(null);
      setCommentStatus('Your comment was posted to the send report.');
    }
  };

  const handleCopyUrl = async (url: string, label: string) => {
    setCopySuccess(null);
    setCopyError(null);
    try {
      if (typeof navigator !== 'undefined' && navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(url);
        setCopySuccess(`${label} copied to your clipboard.`);
        setManualCopyUrl(null);
      } else {
        throw new Error('Clipboard write operation unavailable.');
      }
    } catch {
      setCopyError('Direct clipboard copy failed. Please copy the link manually below.');
      setManualCopyUrl(url);
    }
  };

  const sendUrl =
    typeof window !== 'undefined'
      ? `${window.location.origin}/app/send/${postId}`
      : `/app/send/${postId}`;
  const routeUrl =
    typeof window !== 'undefined' && route
      ? `${window.location.origin}/app/route/${route.id}`
      : `/app/route/${route?.id || ''}`;

  return (
    <article className="b-page" aria-labelledby="send-title">
      <div className="b-page-header">
        <Link href="/app" className="b-button b-button-ghost">
          <ArrowLeftIcon />
          Back to Feed
        </Link>
        <div className="b-inline">
          <span className="b-status b-status-sent">
            <CheckmarkIcon className="w-3.5 h-3.5" />
            Sent
          </span>
          <span className="b-eyebrow">Verified Send</span>
        </div>
      </div>

      <header className="b-panel b-stack">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-slate-800 border border-stone-700 flex items-center justify-center font-bold text-stone-200">
              {authorName.slice(0, 2)}
            </div>
            <div>
              {isMaya ? (
                <Link
                  href="/app/climber/maya"
                  className="text-lg font-semibold text-stone-100 hover:text-indigo-400 hover:underline inline-flex items-center gap-1.5 min-h-[44px]"
                >
                  {authorName}
                  <span className="text-xs text-stone-400 font-normal">View climber</span>
                </Link>
              ) : (
                <span className="text-lg font-semibold text-stone-100">{authorName}</span>
              )}
              <div className="text-xs text-stone-400">{displayDate}</div>
            </div>
          </div>

          {isMaya && (
            <button
              type="button"
              onClick={() => setFollowing(!followingMaya)}
              aria-pressed={followingMaya}
              className={`b-button ${followingMaya ? 'b-button-ghost' : 'b-button-primary'}`}
            >
              {followingMaya ? 'Following Maya' : '+ Follow Maya'}
            </button>
          )}
        </div>

        <div className="pt-2 border-t border-stone-800">
          <div className="b-eyebrow text-stone-400 mb-1">
            {route ? `${route.crag} · ${route.type} · ${route.height}` : 'Outdoor Climb'}
          </div>
          <h1 id="send-title" className="text-3xl sm:text-4xl font-semibold italic text-stone-100">
            <span className="b-serif text-indigo-400 mr-2">{route?.grade || '5.12a'}</span>
            {route ? (
              <Link href={`/app/route/${route.id}`} className="b-serif hover:underline inline-flex items-center min-h-[44px]">
                {route.name}
              </Link>
            ) : (
              <span className="b-serif">Redpoint Ridge</span>
            )}
          </h1>
        </div>

        {isMaya && (
          <div className="mt-2">
            <Photo
              src="/boarded/redpoint-ridge.webp"
              alt="Maya K. clipping quickdraw on Redpoint Ridge limestone overhang"
            />
          </div>
        )}

        <div className="b-shelf b-stack">
          <div className="b-facts">
            <span className="b-fact-item">
              <strong className="text-stone-200">Attempts:</strong> {attemptsCount}
            </span>
            <span className="text-stone-600" aria-hidden="true">•</span>
            <span className="b-fact-item">
              <strong className="text-stone-200">Style:</strong> {route?.style || 'Overhang'}
            </span>
            <span className="text-stone-600" aria-hidden="true">•</span>
            <span className="b-fact-item">
              <strong className="text-stone-200">Rock:</strong> {route?.rock || 'Limestone'}
            </span>
          </div>

          {caption.trim() ? (
            <blockquote className="b-result-card-notes">
              &ldquo;{caption}&rdquo;
            </blockquote>
          ) : null}
        </div>

        <div className="b-inline pt-2">
          <button
            type="button"
            onClick={handleToggleLike}
            aria-pressed={isLiked}
            className="b-action-chip"
            data-active={isLiked ? 'true' : undefined}
          >
            <HeartIcon active={isLiked} />
            <span>{cheersCount} Cheers</span>
          </button>

          {route && (
            <button
              type="button"
              onClick={handleToggleSave}
              aria-pressed={isSaved}
              className="b-action-chip"
              data-active={isSaved ? 'true' : undefined}
            >
              <BookmarkIcon active={isSaved} />
              <span>{isSaved ? 'Saved Route' : 'Save Route'}</span>
            </button>
          )}

          <a href="#comments" className="b-action-chip">
            <ChatBubbleIcon />
            <span>{postComments.length} Comments</span>
          </a>

          <a href="#share" className="b-action-chip">
            <ShareNodesIcon />
            <span>Share Link</span>
          </a>
        </div>
      </header>

      {/* Share Section (#share) */}
      <section id="share" className="b-panel b-stack" aria-labelledby="share-section-heading">
        <div className="flex items-center justify-between flex-wrap gap-2">
          <h2 id="share-section-heading" className="text-xl font-semibold text-stone-100">
            Share Climb Report
          </h2>
          <span className="b-eyebrow">Private Direct Links</span>
        </div>
        <p className="b-muted text-sm">
          No external auto-sharing. You can copy the exact send report or route URL to send directly to your climbing partner.
        </p>

        {copySuccess && (
          <div role="status" aria-live="polite" className="p-3 bg-emerald-950/60 border border-emerald-500/50 rounded-md text-emerald-300 text-sm flex items-center gap-2">
            <CheckmarkIcon className="w-4 h-4 text-emerald-400 flex-shrink-0" />
            <span>{copySuccess}</span>
          </div>
        )}

        {copyError && (
          <div role="alert" className="p-3 bg-amber-950/60 border border-amber-500/50 rounded-md text-amber-300 text-sm">
            {copyError}
          </div>
        )}

        {manualCopyUrl && (
          <div className="b-field">
            <label htmlFor="manual-copy-input" className="text-xs font-semibold text-stone-300">
              Manual copy link (select all):
            </label>
            <input
              id="manual-copy-input"
              type="text"
              readOnly
              value={manualCopyUrl}
              onFocus={(e) => e.target.select()}
              className="w-full text-xs font-mono bg-stone-900 text-stone-200 border border-stone-700 p-2 rounded min-h-[44px]"
            />
          </div>
        )}

        <div className="b-inline pt-1">
          <button
            type="button"
            onClick={() => handleCopyUrl(sendUrl, 'Send report URL')}
            className="b-button b-button-primary"
          >
            <CopyDocIcon />
            Copy Send Link
          </button>

          {route && (
            <button
              type="button"
              onClick={() => handleCopyUrl(routeUrl, 'Route URL')}
              className="b-button"
            >
              <ShareNodesIcon />
              Copy Route Link
            </button>
          )}
        </div>
      </section>

      {/* Comments Section (#comments) */}
      <section id="comments" className="b-panel b-stack" aria-labelledby="comments-heading">
        <div className="flex items-center justify-between flex-wrap gap-2">
          <h2 id="comments-heading" className="text-xl font-semibold text-stone-100">
            Community Comments ({postComments.length})
          </h2>
          <span className="b-eyebrow">Climber Discussion</span>
        </div>

        <ul className="b-comment-list" role="list">
          {postComments.map((c) => (
            <li key={c.id} className="b-comment-item">
              <div className="b-comment-header">
                <span className="b-comment-author">{c.author}</span>
                {c.createdAt && (
                  <span className="b-comment-time">
                    {c.createdAt.includes('T') ? c.createdAt.split('T')[0] : c.createdAt}
                  </span>
                )}
              </div>
              <p className="b-comment-body">{c.text}</p>
            </li>
          ))}
        </ul>

        <form onSubmit={handleAddComment} className="b-field pt-3 border-t border-stone-800">
          <label htmlFor="new-comment-text" className="font-semibold text-stone-200 text-sm">
            Leave a comment for {authorName}:
          </label>
          <textarea
            id="new-comment-text"
            ref={commentInputRef}
            rows={3}
            value={commentText}
            onChange={(e) => {
              setCommentText(e.target.value);
              if (commentError) setCommentError(null);
            }}
            placeholder="Share your beta, congratulations, or questions on the moves..."
            aria-invalid={commentError ? 'true' : 'false'}
            aria-describedby={commentError ? 'comment-error-msg' : undefined}
            className="w-full resize-y"
          />

          {commentError && (
            <div id="comment-error-msg" role="alert" className="b-errors">
              {commentError}
            </div>
          )}

          {commentStatus && (
            <div role="status" aria-live="polite" className="text-xs text-emerald-400 font-medium">
              {commentStatus}
            </div>
          )}

          <div className="flex justify-between items-center pt-2">
            <span className="text-xs text-stone-400">
              {commentText.length} / 500 characters
            </span>
            <button type="submit" className="b-button b-button-primary">
              Post Comment
            </button>
          </div>
        </form>
      </section>
    </article>
  );
}

/* ==========================================================================
   2. Route Detail Component (/app/route/[routeId])
   ========================================================================== */

export interface RouteDetailProps {
  routeId: string;
}

export function RouteDetail({ routeId }: RouteDetailProps) {
  const { savedRouteIds, toggleSave, entries } = useJournal();
  const route = routes.find((r) => r.id === routeId);

  if (!route) {
    return (
      <div className="b-page" role="region" aria-labelledby="route-not-found-title">
        <div className="b-page-header">
          <Link href="/app/explore" className="b-button b-button-ghost">
            <ArrowLeftIcon />
            Back to Explore
          </Link>
          <span className="b-eyebrow">Unknown Route</span>
        </div>
        <div className="b-panel b-stack">
          <h1 id="route-not-found-title" className="b-serif text-2xl font-bold">
            Route not found
          </h1>
          <p className="b-muted">
            The route id &quot;{routeId}&quot; does not match any route in the local directory.
          </p>
          <div className="b-inline">
            <Link href="/app/explore" className="b-button b-button-primary">
              Browse Available Routes
            </Link>
            <Link href="/app" className="b-button">
              Return to Feed
            </Link>
          </div>
        </div>
      </div>
    );
  }

  const isSaved = savedRouteIds.includes(route.id);
  const routeEntries = entries.filter((e) => e.routeId === route.id);
  const isRedpointRidge = route.id === 'redpoint-ridge';

  const termDefinitions = [
    {
      term: 'What is a Redpoint?',
      body: 'In sport climbing, a redpoint means cleanly ascending a route from ground to anchor on lead without falling or resting on rope gear, having practiced or rehearsed the moves previously.',
    },
    {
      term: `What does ${route.type} climbing mean?`,
      body:
        route.type === 'Sport'
          ? 'Sport climbing involves routes equipped with permanent pre-placed expansion bolts and hangers in the rock. Climbers clip quickdraws into bolts as they ascend for protection.'
          : 'Bouldering focuses on short, powerful problem sequences on natural boulders or lower rock formations without ropes, protected from ground impact by specialized crash pads and active spotters.',
    },
    {
      term: `What characterizes ${route.rock} rock?`,
      body:
        route.rock === 'Limestone'
          ? 'Limestone is a sedimentary rock characterized by pocketed seams, natural tufas, edge shelves, and dramatic roofs, commonly found in deep canyons and overhanging river crags.'
          : 'Granite is an intrusive igneous rock renowned for crisp friction crystals, side-pull flakes, compression slopers, and demanding technical foot smears.',
    },
    {
      term: `How to tackle an ${route.style} angle?`,
      body:
        route.style === 'Overhang'
          ? 'Overhanging rock requires continuous body tension, deliberate heel and toe hooking to relieve forearm weight, and rapid, confident clip transitions before pump sets in.'
          : route.style === 'Compression'
          ? 'Compression climbing demands squeezing opposing rock features with both arms and feet to maintain equilibrium on steep, holdless planes.'
          : 'Vertical face climbing prioritizes precise toe placements on micro-edges, disciplined center of gravity control, and efficient breathing through balance crux moves.',
    },
  ];

  return (
    <article className="b-page" aria-labelledby="route-heading">
      <div className="b-page-header">
        <Link href="/app/explore" className="b-button b-button-ghost">
          <ArrowLeftIcon />
          Back to Explore
        </Link>
        <span className="b-eyebrow">{route.crag} Crag Directory</span>
      </div>

      <div className="b-panel b-stack">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <div className="b-eyebrow text-stone-400 mb-1">
              {route.crag} · {route.type} · {route.height}
            </div>
            <h1 id="route-heading" className="text-3xl sm:text-4xl font-semibold italic text-stone-100">
              <span className="b-serif text-indigo-400 mr-2">{route.grade}</span>
              <span className="b-serif">{route.name}</span>
            </h1>
          </div>

          <div className="b-inline">
            <button
              type="button"
              onClick={() => toggleSave(route.id)}
              aria-pressed={isSaved}
              className={`b-button ${isSaved ? 'b-button-primary' : ''}`}
            >
              <BookmarkIcon active={isSaved} />
              <span>{isSaved ? 'Saved to Wishlist' : 'Save Route'}</span>
            </button>

            <Link href={`/app/log?route=${route.id}`} className="b-button b-button-primary">
              <PlusSymbolIcon />
              Log an attempt
            </Link>
          </div>
        </div>

        {isRedpointRidge ? (
          <Photo
            src="/boarded/redpoint-ridge.webp"
            alt="Redpoint Ridge limestone route with overhanging face and chalked pockets"
          />
        ) : (
          <div className="b-shelf p-4 text-center text-stone-400 text-sm">
            <span className="b-serif text-lg text-stone-200 block mb-1">
              {route.rock} {route.type} Venue
            </span>
            Authentic natural outdoor terrain at {route.crag}. Topo line mapped below.
          </div>
        )}

        <div className="b-shelf">
          <div className="b-facts">
            <div className="b-fact-item">
              <span className="text-stone-400">Crag:</span>
              <strong className="text-stone-200">{route.crag}</strong>
            </div>
            <span className="text-stone-600" aria-hidden="true">•</span>
            <div className="b-fact-item">
              <span className="text-stone-400">Discipline:</span>
              <strong className="text-stone-200">{route.type}</strong>
            </div>
            <span className="text-stone-600" aria-hidden="true">•</span>
            <div className="b-fact-item">
              <span className="text-stone-400">Height:</span>
              <strong className="text-stone-200">{route.height}</strong>
            </div>
            <span className="text-stone-600" aria-hidden="true">•</span>
            <div className="b-fact-item">
              <span className="text-stone-400">Rock Type:</span>
              <strong className="text-stone-200">{route.rock}</strong>
            </div>
            <span className="text-stone-600" aria-hidden="true">•</span>
            <div className="b-fact-item">
              <span className="text-stone-400">Style / Profile:</span>
              <strong className="text-stone-200">{route.style}</strong>
            </div>
          </div>
        </div>

        <div>
          <h2 className="text-sm font-bold uppercase tracking-wider text-stone-400 mb-2">
            Route Description & Beta
          </h2>
          <p className="text-base text-stone-200 leading-relaxed">
            {route.description}
          </p>
        </div>

        {/* Grounded Boulder Specifications (for Boulder routes) */}
        {route.type === 'Boulder' && (
          <div className="b-shelf b-stack">
            <h2 className="text-xs font-bold uppercase tracking-wider text-stone-400">
              Grounded Boulder Specifications
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div>
                <span className="text-stone-400 block font-semibold">Start Configuration:</span>
                <span className="text-stone-200">Sit start on low opposing compression flakes</span>
              </div>
              <div>
                <span className="text-stone-400 block font-semibold">Crux Transition:</span>
                <span className="text-stone-200">Powerful heel hook placement across 40° granite roof</span>
              </div>
              <div>
                <span className="text-stone-400 block font-semibold">Finish / Topout:</span>
                <span className="text-stone-200">Committed mantle over rounded granite boulder lip (no chains)</span>
              </div>
              <div>
                <span className="text-stone-400 block font-semibold">Protection &amp; Safety:</span>
                <span className="text-stone-200">2-3 crash pads and attentive spotter required for talus landing</span>
              </div>
            </div>
          </div>
        )}

        {/* Topo Visualizer (Decorative, grounded by route type) */}
        <div className="b-topo-wrapper" aria-labelledby="topo-heading">
          <div className="flex items-center justify-between">
            <h2 id="topo-heading" className="text-sm font-bold uppercase tracking-wider text-stone-300">
              Decorative Topo Line
            </h2>
            <span className="text-xs text-stone-400 font-mono">
              {route.type === 'Boulder'
                ? 'Roof Line · Pad Landing · Mantle Topout'
                : route.id === 'redpoint-ridge'
                ? '11 Bolts · Single Pitch'
                : 'Bolted Line · Single Pitch'}
            </span>
          </div>

          {route.type === 'Boulder' ? (
            <svg
              className="b-topo-svg"
              viewBox="0 0 600 200"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              role="img"
              aria-label={`Topo diagram for boulder problem ${route.name} showing sit start, roof crux, and mantle topout`}
            >
              <path
                d="M0 190 Q150 160 300 170 T600 150 L600 200 L0 200 Z"
                fill="#141824"
              />
              {/* Crash pad landing zone */}
              <line
                x1="40"
                y1="190"
                x2="320"
                y2="190"
                stroke="#345CFF"
                strokeWidth="4"
                strokeDasharray="6 4"
              />
              <text x="180" y="184" fill="#9ca3af" fontSize="11" textAnchor="middle">
                Crash Pad Landing Zone
              </text>

              {/* Roof overhang outline */}
              <path
                d="M 60 170 C 140 165, 200 135, 280 120 S 420 85, 520 40"
                stroke="#345CFF"
                strokeWidth="4"
                strokeLinecap="round"
              />

              {/* Low sit start */}
              <circle cx="60" cy="170" r="7" fill="#F4F2EB" stroke="#0A0B10" strokeWidth="2" />
              <circle cx="160" cy="150" r="5" fill="#345CFF" />
              <circle cx="220" cy="135" r="5" fill="#345CFF" />
              {/* Roof Crux */}
              <circle cx="280" cy="120" r="8" fill="#FF5C5C" stroke="#0A0B10" strokeWidth="2" />
              <circle cx="370" cy="95" r="5" fill="#345CFF" />
              <circle cx="450" cy="65" r="5" fill="#345CFF" />
              {/* Mantle topout */}
              <circle cx="520" cy="40" r="8" fill="#F4F2EB" stroke="#0A0B10" strokeWidth="2" />

              <text x="60" y="154" fill="#9ca3af" fontSize="11" textAnchor="middle">Sit Start</text>
              <text x="280" y="104" fill="#ff8585" fontSize="11" fontWeight="bold" textAnchor="middle">Crux (Compression &amp; Heel Hook)</text>
              <text x="520" y="24" fill="#F4F2EB" fontSize="11" fontWeight="bold" textAnchor="middle">Mantle Topout</text>
            </svg>
          ) : (
            <svg
              className="b-topo-svg"
              viewBox="0 0 600 200"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              role="img"
              aria-label={`Topo diagram for ${route.name} showing bolt line and crux location`}
            >
              <path
                d="M0 190 Q150 160 300 170 T600 150 L600 200 L0 200 Z"
                fill="#141824"
              />
              <path
                d="M0 120 Q200 80 400 100 T600 70"
                stroke="rgba(244, 242, 235, 0.08)"
                strokeWidth="2"
                strokeDasharray="4 4"
              />

              <path
                d="M 60 180 C 140 150, 180 120, 260 110 S 420 70, 530 30"
                stroke="#345CFF"
                strokeWidth="4"
                strokeLinecap="round"
              />

              <circle cx="60" cy="180" r="6" fill="#F4F2EB" stroke="#0A0B10" strokeWidth="2" />
              <circle cx="150" cy="142" r="5" fill="#345CFF" />
              <circle cx="210" cy="122" r="5" fill="#345CFF" />
              <circle cx="260" cy="110" r="7" fill="#FF5C5C" stroke="#0A0B10" strokeWidth="2" />
              <circle cx="340" cy="92" r="5" fill="#345CFF" />
              <circle cx="420" cy="70" r="5" fill="#345CFF" />
              <circle cx="470" cy="50" r="5" fill="#345CFF" />
              <circle cx="530" cy="30" r="7" fill="#F4F2EB" stroke="#0A0B10" strokeWidth="2" />

              <text x="60" y="198" fill="#9ca3af" fontSize="11" textAnchor="middle">Start</text>
              <text x="260" y="98" fill="#ff8585" fontSize="11" fontWeight="bold" textAnchor="middle">Crux (Bolt 4)</text>
              <text x="530" y="20" fill="#F4F2EB" fontSize="11" fontWeight="bold" textAnchor="middle">Anchor</text>
            </svg>
          )}

          <div className="b-topo-legend">
            <div className="b-topo-legend-item">
              <span className="b-topo-dot bg-indigo-500" />
              <span>Route Path Line</span>
            </div>
            <div className="b-topo-legend-item">
              <span className="b-topo-dot bg-red-500" />
              <span>{route.type === 'Boulder' ? 'Roof Crux Moves' : 'Crux Sequence'}</span>
            </div>
            <div className="b-topo-legend-item">
              <span className="b-topo-dot bg-[#F4F2EB]" />
              <span>{route.type === 'Boulder' ? 'Mantle Topout Lip' : 'Chains / Anchor'}</span>
            </div>
          </div>
        </div>

        {/* Climbing Term Definitions */}
        <div>
          <h2 className="text-sm font-bold uppercase tracking-wider text-stone-400 mb-3">
            Climbing Vocabulary & Field Guide
          </h2>
          <div className="b-stack">
            {termDefinitions.map((t, idx) => (
              <details key={idx} className="b-term-details">
                <summary className="b-term-summary">{t.term}</summary>
                <p className="b-term-body">{t.body}</p>
              </details>
            ))}
          </div>
        </div>

        {/* Community Activity on this route */}
        <section className="pt-2 border-t border-stone-800" aria-labelledby="route-ticks-heading">
          <h2 id="route-ticks-heading" className="text-base font-bold text-stone-200 mb-3">
            Ascents & Community Ticks
          </h2>

          <div className="b-stack">
            {isRedpointRidge && (
              <div className="b-shelf flex items-center justify-between flex-wrap gap-2">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-semibold text-stone-100">Maya K.</span>
                    <span className="b-status b-status-sent text-xs">Sent</span>
                  </div>
                  <div className="text-xs text-stone-400">
                    Sep 6, 2026 · 6 attempts · &ldquo;Six tries. One quiet moment...&rdquo;
                  </div>
                </div>
                <Link href="/app/send/maya-redpoint" className="b-button b-button-ghost text-xs">
                  View Send Report →
                </Link>
              </div>
            )}

            {routeEntries.length > 0 ? (
              routeEntries.map((e) => (
                <div key={e.id} className="b-shelf flex items-center justify-between flex-wrap gap-2">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-stone-100">You (Alex R.)</span>
                      <span className={`b-status ${e.outcome === 'sent' ? 'b-status-sent' : 'b-status-attempt'} text-xs`}>
                        {e.outcome === 'sent' ? 'Sent' : 'Attempted'}
                      </span>
                    </div>
                    <div className="text-xs text-stone-400">
                      {e.date} · {e.attempts} attempts {e.notes ? `· ${e.notes.slice(0, 40)}...` : ''}
                    </div>
                  </div>
                  <Link href={`/app/attempt/${e.id}`} className="b-button b-button-ghost text-xs">
                    View Log →
                  </Link>
                </div>
              ))
            ) : (
              !isRedpointRidge && (
                <p className="text-sm text-stone-400 italic">
                  No personal ascents logged for this route yet. Be the first to record an attempt!
                </p>
              )
            )}
          </div>
        </section>
      </div>
    </article>
  );
}

/* ==========================================================================
   3. Attempt Detail Component (/app/attempt/[id])
   ========================================================================== */

export interface AttemptDetailProps {
  entryId: string;
}

export function AttemptDetail({ entryId }: AttemptDetailProps) {
  const { entries, markSent, ready } = useJournal();
  const entry = entries.find((e) => e.id === entryId);
  const route = entry ? routes.find((r) => r.id === entry.routeId) : null;

  const [transitionError, setTransitionError] = useState<string | null>(null);

  if (!ready && !entry) {
    return (
      <div className="b-page" aria-busy="true">
        <div className="b-panel text-center py-16">
          <div className="inline-block animate-pulse text-stone-300 text-sm font-medium mb-2">
            Loading climbing journal...
          </div>
          <p className="b-muted text-xs">Retrieving attempt record</p>
        </div>
      </div>
    );
  }

  if (!entry) {
    return (
      <div className="b-page" role="region" aria-labelledby="attempt-not-found-heading">
        <div className="b-page-header">
          <Link href="/app/profile" className="b-button b-button-ghost">
            <ArrowLeftIcon />
            Back to Profile
          </Link>
          <span className="b-eyebrow">Entry Not Found</span>
        </div>
        <div className="b-panel b-stack">
          <h1 id="attempt-not-found-heading" className="b-serif text-2xl font-bold">
            Attempt record not found
          </h1>
          <p className="b-muted">
            The attempt record with id &quot;{entryId}&quot; does not exist in your local journal.
          </p>
          <div className="b-inline">
            <Link href="/app/log" className="b-button b-button-primary">
              Log a New Attempt
            </Link>
            <Link href="/app/profile" className="b-button">
              View Journal
            </Link>
          </div>
        </div>
      </div>
    );
  }

  const isSent = entry.outcome === 'sent';

  const handleMarkSent = () => {
    setTransitionError(null);
    const res = markSent(entry.id);
    if ('error' in res) {
      setTransitionError(res.error);
    }
  };

  return (
    <article className="b-page" aria-labelledby="attempt-heading">
      <div className="b-page-header">
        <Link href="/app/profile" className="b-button b-button-ghost">
          <ArrowLeftIcon />
          Back to Profile
        </Link>
        <span className="b-eyebrow">Logged Attempt Record</span>
      </div>

      <div className="b-panel b-stack">
        <div className="flex items-start justify-between flex-wrap gap-2">
          <div>
            <div className="b-eyebrow text-stone-400 mb-1">
              Logged Session · {entry.date}
            </div>
            <h1 id="attempt-heading" className="text-3xl font-semibold italic text-stone-100">
              <span className="b-serif text-indigo-400 mr-2">{route?.grade || 'Project'}</span>
              <Link href={`/app/route/${entry.routeId}`} className="b-serif hover:underline inline-flex items-center min-h-[44px]">
                {route?.name || entry.routeId}
              </Link>
            </h1>
          </div>

          <div>
            {isSent ? (
              <span className="b-status b-status-sent">
                <CheckmarkIcon className="w-3.5 h-3.5" />
                Sent / Ticked
              </span>
            ) : (
              <span className="b-status b-status-attempt">
                Attempted / Working Beta
              </span>
            )}
          </div>
        </div>

        <div className="b-shelf b-stack">
          <div className="b-facts">
            <div className="b-fact-item">
              <span className="text-stone-400">Date:</span>
              <strong className="text-stone-200">{entry.date}</strong>
            </div>
            <span className="text-stone-600" aria-hidden="true">•</span>
            <div className="b-fact-item">
              <span className="text-stone-400">Attempts:</span>
              <strong className="text-stone-200">{entry.attempts}</strong>
            </div>
            {route && (
              <>
                <span className="text-stone-600" aria-hidden="true">•</span>
                <div className="b-fact-item">
                  <span className="text-stone-400">Crag:</span>
                  <strong className="text-stone-200">{route.crag}</strong>
                </div>
              </>
            )}
          </div>

          {entry.conditions && (
            <div>
              <span className="text-xs font-semibold uppercase text-stone-400 block mb-0.5">
                Weather & Conditions:
              </span>
              <p className="text-sm text-stone-300 m-0">{entry.conditions}</p>
            </div>
          )}

          {entry.notes && (
            <div>
              <span className="text-xs font-semibold uppercase text-stone-400 block mb-0.5">
                Session Beta & Notes:
              </span>
              <p className="text-sm text-stone-300 m-0 leading-relaxed">{entry.notes}</p>
            </div>
          )}
        </div>

        {transitionError && (
          <div role="alert" className="b-errors p-3 bg-red-950/50 border border-red-500 rounded">
            {transitionError}
          </div>
        )}

        {!isSent ? (
          <div className="p-4 rounded-lg bg-indigo-950/30 border border-indigo-500/40 b-stack">
            <div className="flex items-center gap-2">
              <span className="b-eyebrow text-indigo-400">Did you send?</span>
            </div>
            <p className="text-sm text-stone-200 m-0 leading-relaxed">
              <strong>Completed the climb without falling or resting on the rope</strong>
            </p>
            <p className="text-xs text-stone-400 m-0">
              Marking as sent records a clean tick in your climbing journal and unlocks the shareable result card.
            </p>
            <div>
              <button
                type="button"
                onClick={handleMarkSent}
                className="b-button b-button-primary"
              >
                <CheckmarkIcon />
                Mark as sent
              </button>
            </div>
          </div>
        ) : (
          <div className="p-4 rounded-lg bg-emerald-950/30 border border-emerald-500/40 b-stack">
            <div className="flex items-center gap-2 text-emerald-400 font-semibold text-sm">
              <CheckmarkIcon className="w-5 h-5" />
              Climb verified as Sent! Clean tick recorded.
            </div>
            <p className="text-xs text-stone-300 m-0">
              Your send is recorded in your profile. You can now compose a shareable result card to celebrate or download the graphic.
            </p>
            <div className="b-inline">
              <Link href={`/app/share/${entry.id}`} className="b-button b-button-primary">
                Create result card →
              </Link>
            </div>
          </div>
        )}

        <div className="b-inline pt-2 border-t border-stone-800">
          <Link href="/app/log" className="b-button">
            Log another session
          </Link>
          <Link href="/app/profile" className="b-button">
            View profile & stats
          </Link>
        </div>
      </div>
    </article>
  );
}
