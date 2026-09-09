'use client';

import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import * as Dialog from '@radix-ui/react-dialog';
import {
  routes,
  validateAttempt,
  type Entry,
  type AttemptInput,
} from '@/lib/boarded/journal';
import { useJournal } from '@/lib/boarded/store';

const DRAFT_STORAGE_KEY = 'boarded-attempt-draft-v1';

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

function DownloadIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3" />
    </svg>
  );
}

function CopyIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
      <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 0 1-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 0 1 1.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 0 0-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375-9-9" />
    </svg>
  );
}

function TrashIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
      <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
    </svg>
  );
}

/* ==========================================================================
   1. Log Attempt Form Component (/app/log)
   ========================================================================== */

export interface LogAttemptFormProps {
  initialRouteId?: string;
}

export function LogAttemptForm({ initialRouteId }: LogAttemptFormProps) {
  const router = useRouter();
  const { recordAttempt } = useJournal();

  // Form input states
  const [routeId, setRouteId] = useState<string>(() => {
    if (initialRouteId && routes.some((r) => r.id === initialRouteId)) {
      return initialRouteId;
    }
    return routes[0]?.id || '';
  });

  const [date, setDate] = useState<string>('2026-09-06');
  const [attempts, setAttempts] = useState<string>('1');
  const [conditions, setConditions] = useState<string>('');
  const [notes, setNotes] = useState<string>('');
  const [isDraftHydrated, setIsDraftHydrated] = useState<boolean>(false);
  const [unknownRouteNotice, setUnknownRouteNotice] = useState<string | null>(null);
  // Error states
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Focus ref for error summary accessibility
  const errorSummaryRef = useRef<HTMLDivElement>(null);

  // Restore draft from sessionStorage on mount (gate saving until hydrated)
  useEffect(() => {
    try {
      if (typeof window !== 'undefined' && window.sessionStorage) {
        const saved = window.sessionStorage.getItem(DRAFT_STORAGE_KEY);
        if (saved) {
          const parsed = JSON.parse(saved);
          if (parsed && typeof parsed === 'object') {
            if (initialRouteId) {
              if (routes.some((r) => r.id === initialRouteId)) {
                setRouteId(initialRouteId);
              } else {
                setUnknownRouteNotice(`Requested route "${initialRouteId}" was not found in directory. Defaulted to ${routes[0]?.name}.`);
                if (parsed.routeId && routes.some((r) => r.id === parsed.routeId)) {
                  setRouteId(parsed.routeId);
                }
              }
            } else if (parsed.routeId && routes.some((r) => r.id === parsed.routeId)) {
              setRouteId(parsed.routeId);
            }

            if (typeof parsed.date === 'string') setDate(parsed.date);
            if (typeof parsed.attempts === 'number' || typeof parsed.attempts === 'string') {
              setAttempts(String(parsed.attempts));
            }
            if (typeof parsed.conditions === 'string') setConditions(parsed.conditions);
            if (typeof parsed.notes === 'string') setNotes(parsed.notes);
          }
        } else if (initialRouteId) {
          if (routes.some((r) => r.id === initialRouteId)) {
            setRouteId(initialRouteId);
          } else {
            setUnknownRouteNotice(`Requested route "${initialRouteId}" was not found in directory. Defaulted to ${routes[0]?.name}.`);
          }
        }
      }
    } catch {
      // sessionStorage read failure tolerated
    } finally {
      setIsDraftHydrated(true);
    }
  }, [initialRouteId]);

  // Update routeId if initialRouteId prop changes from direct URL reload/navigation
  useEffect(() => {
    if (initialRouteId) {
      if (routes.some((r) => r.id === initialRouteId)) {
        setRouteId(initialRouteId);
        setUnknownRouteNotice(null);
      } else {
        setUnknownRouteNotice(`Requested route "${initialRouteId}" was not found in directory. Defaulted to ${routes[0]?.name}.`);
      }
    }
  }, [initialRouteId]);

  // Save draft locally to sessionStorage only AFTER initial hydration
  useEffect(() => {
    if (!isDraftHydrated) return;
    try {
      if (typeof window !== 'undefined' && window.sessionStorage) {
        const draft = { routeId, date, attempts, conditions, notes };
        window.sessionStorage.setItem(DRAFT_STORAGE_KEY, JSON.stringify(draft));
      }
    } catch (err: unknown) {
      // Storage failure surfaced without crash
      console.warn('SessionStorage draft write error:', err);
    }
  }, [isDraftHydrated, routeId, date, attempts, conditions, notes]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitError(null);

    const trimmedAttempts = attempts.trim();
    const parsedAttempts = trimmedAttempts === '' ? NaN : Number(trimmedAttempts);

    const payload: AttemptInput = {
      routeId,
      date: date.trim(),
      attempts: parsedAttempts,
      conditions: conditions.trim(),
      notes: notes.trim(),
    };
    const validationErrors = validateAttempt(payload);
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors);
      // Accessibility requirement: Focus error summary on failed validation
      setTimeout(() => {
        errorSummaryRef.current?.focus();
      }, 50);
      return;
    }

    setErrors({});
    const res = recordAttempt(payload);

    if ('error' in res) {
      // Preserve all entered values; display error banner and focus summary
      setSubmitError(res.error);
      setTimeout(() => {
        errorSummaryRef.current?.focus();
      }, 50);
      return;
    }

    // Clean up draft storage on successful submission
    try {
      if (typeof window !== 'undefined' && window.sessionStorage) {
        window.sessionStorage.removeItem(DRAFT_STORAGE_KEY);
      }
    } catch {
      // ignore
    }

    // Navigate to attempt detail
    router.push(`/app/attempt/${res.id}`);
  };

  const selectedRoute = routes.find((r) => r.id === routeId);
  const errorCount = Object.keys(errors).length + (submitError ? 1 : 0);

  return (
    <article className="b-page" aria-labelledby="log-form-title">
      <div className="b-page-header">
        <Link href="/app" className="b-button b-button-ghost">
          <ArrowLeftIcon />
          Back to Feed
        </Link>
        <span className="b-eyebrow">Session Logger</span>
      </div>

      <div className="b-panel b-stack">
        <div>
          <div className="b-eyebrow text-stone-400 mb-1">Field Instrument</div>
          <h1 id="log-form-title" className="b-serif text-3xl sm:text-4xl font-semibold italic text-stone-100">
            Record a Climbing Attempt
          </h1>
          <p className="b-muted text-sm mt-1">
            Log your session tries, beta notes, and conditions. All entries are recorded locally.
            Completed sends can be verified and published after logging.
          </p>
        </div>

        {unknownRouteNotice && (
          <div role="status" className="p-3 bg-amber-950/40 border border-amber-500/40 rounded text-amber-200 text-xs">
            {unknownRouteNotice}
          </div>
        )}

        {/* Accessible Error Summary */}
        {errorCount > 0 && (
          <div
            ref={errorSummaryRef}
            tabIndex={-1}
            role="alert"
            aria-labelledby="error-summary-title"
            className="b-error-summary"
          >
            <h2 id="error-summary-title" className="b-error-summary-title">
              <svg className="w-5 h-5 text-red-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
              </svg>
              Please correct the {errorCount} error{errorCount > 1 ? 's' : ''} below
            </h2>
            <ul className="b-error-summary-list">
              {submitError && <li>{submitError}</li>}
              {errors.routeId && (
                <li>
                  <a href="#log-route">{errors.routeId}</a>
                </li>
              )}
              {errors.date && (
                <li>
                  <a href="#log-date">{errors.date}</a>
                </li>
              )}
              {errors.attempts && (
                <li>
                  <a href="#log-attempts">{errors.attempts}</a>
                </li>
              )}
              {errors.conditions && (
                <li>
                  <a href="#log-conditions">{errors.conditions}</a>
                </li>
              )}
              {errors.notes && (
                <li>
                  <a href="#log-notes">{errors.notes}</a>
                </li>
              )}
            </ul>
          </div>
        )}

        {/* The Log Form */}
        <form onSubmit={handleSubmit} noValidate className="b-stack">
          {/* Route Field */}
          <div className="b-field">
            <label htmlFor="log-route">
              Target Route <span className="text-indigo-400" aria-hidden="true">*</span>
            </label>
            <select
              id="log-route"
              value={routeId}
              onChange={(e) => {
                setRouteId(e.target.value);
                if (errors.routeId) {
                  const next = { ...errors };
                  delete next.routeId;
                  setErrors(next);
                }
              }}
              aria-invalid={errors.routeId ? 'true' : 'false'}
              aria-describedby={errors.routeId ? 'error-route' : undefined}
            >
              {routes.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name} ({r.grade}) — {r.crag} [{r.type} · {r.rock}]
                </option>
              ))}
            </select>
            {errors.routeId && (
              <span id="error-route" className="b-errors">
                {errors.routeId}
              </span>
            )}
            {selectedRoute && (
              <div className="text-xs text-stone-400 mt-0.5">
                {selectedRoute.height} · {selectedRoute.style} · {selectedRoute.description.slice(0, 70)}...
              </div>
            )}
          </div>

          {/* Date Field */}
          <div className="b-field">
            <label htmlFor="log-date">
              Session Date (YYYY-MM-DD) <span className="text-indigo-400" aria-hidden="true">*</span>
            </label>
            <input
              id="log-date"
              type="text"
              pattern="\d{4}-\d{2}-\d{2}"
              placeholder="2026-09-06"
              value={date}
              onChange={(e) => {
                setDate(e.target.value);
                if (errors.date) {
                  const next = { ...errors };
                  delete next.date;
                  setErrors(next);
                }
              }}
              aria-invalid={errors.date ? 'true' : 'false'}
              aria-describedby={errors.date ? 'error-date' : undefined}
            />
            {errors.date && (
              <span id="error-date" className="b-errors">
                {errors.date}
              </span>
            )}
          </div>

          {/* Attempts Count Field */}
          <div className="b-field">
            <label htmlFor="log-attempts">
              Number of Attempts <span className="text-indigo-400" aria-hidden="true">*</span>
            </label>
            <input
              id="log-attempts"
              type="number"
              min={1}
              max={100}
              step={1}
              value={attempts}
              onChange={(e) => {
                setAttempts(e.target.value);
                if (errors.attempts) {
                  const next = { ...errors };
                  delete next.attempts;
                  setErrors(next);
                }
              }}
              aria-invalid={errors.attempts ? 'true' : 'false'}
              aria-describedby={errors.attempts ? 'error-attempts' : undefined}
            />
            {errors.attempts && (
              <span id="error-attempts" className="b-errors">
                {errors.attempts}
              </span>
            )}
            <span className="text-xs text-stone-400">
              Enter total tries during this climbing session (1 to 100).
            </span>
          </div>

          {/* Conditions Field */}
          <div className="b-field">
            <label htmlFor="log-conditions">Weather & Crag Conditions</label>
            <input
              id="log-conditions"
              type="text"
              maxLength={500}
              placeholder="e.g. Crisp morning, dry limestone pockets, 14°C, slight breeze"
              value={conditions}
              onChange={(e) => {
                setConditions(e.target.value);
                if (errors.conditions) {
                  const next = { ...errors };
                  delete next.conditions;
                  setErrors(next);
                }
              }}
              aria-invalid={errors.conditions ? 'true' : 'false'}
              aria-describedby={errors.conditions ? 'error-conditions' : undefined}
            />
            {errors.conditions && (
              <span id="error-conditions" className="b-errors">
                {errors.conditions}
              </span>
            )}
            <span className="text-xs text-stone-400">
              {conditions.length} / 500 characters
            </span>
          </div>

          {/* Notes Field */}
          <div className="b-field">
            <label htmlFor="log-notes">Session Beta & Progression Notes</label>
            <textarea
              id="log-notes"
              rows={4}
              maxLength={1000}
              placeholder="Working the crux moves, heel hook placement, rest stance after bolt 3, fatigue notes..."
              value={notes}
              onChange={(e) => {
                setNotes(e.target.value);
                if (errors.notes) {
                  const next = { ...errors };
                  delete next.notes;
                  setErrors(next);
                }
              }}
              aria-invalid={errors.notes ? 'true' : 'false'}
              aria-describedby={errors.notes ? 'error-notes' : undefined}
              className="resize-y"
            />
            {errors.notes && (
              <span id="error-notes" className="b-errors">
                {errors.notes}
              </span>
            )}
            <span className="text-xs text-stone-400">
              {notes.length} / 1000 characters
            </span>
          </div>

          {/* Submit Actions */}
          <div className="b-inline pt-4 border-t border-stone-800 justify-between">
            <Link href="/app" className="b-button b-button-ghost">
              Cancel
            </Link>
            <button type="submit" className="b-button b-button-primary">
              <CheckmarkIcon />
              Save Attempt to Journal
            </button>
          </div>
        </form>
      </div>
    </article>
  );
}

/* ==========================================================================
   2. Share Flow Component (/app/share/[id])
   ========================================================================== */

export interface ShareFlowProps {
  entryId: string;
}

export function ShareFlow({ entryId }: ShareFlowProps) {
  const { entries, publish, ready } = useJournal();
  const entry = entries.find((e) => e.id === entryId);
  const route = entry ? routes.find((r) => r.id === entry.routeId) : null;

  const [caption, setCaption] = useState(() =>
    entry?.published ? (entry.caption ?? '') : entry?.notes || 'Clean send on the project!'
  );
  const isUserEditedRef = useRef(false);
  const hydratedEntryIdRef = useRef<string | null>(null);

  // Hydrate saved caption from loaded entry on direct reload/navigation without clobbering user edits
  useEffect(() => {
    if (entry && !isUserEditedRef.current && hydratedEntryIdRef.current !== entry.id) {
      hydratedEntryIdRef.current = entry.id;
      setCaption(entry.published ? (entry.caption ?? '') : entry.notes || 'Clean send on the project!');
    }
  }, [entry]);

  const [publishStatus, setPublishStatus] = useState<string | null>(null);
  const [publishError, setPublishError] = useState<string | null>(null);
  const [copySuccess, setCopySuccess] = useState<string | null>(null);
  const [copyError, setCopyError] = useState<string | null>(null);
  const [manualCopyUrl, setManualCopyUrl] = useState<string | null>(null);
  const [downloadState, setDownloadState] = useState<'idle' | 'loading'>('idle');
  const [downloadError, setDownloadError] = useState<string | null>(null);


  if (!ready && !entry) {
    return (
      <div className="b-page" aria-busy="true">
        <div className="b-panel text-center py-16">
          <div className="inline-block animate-pulse text-stone-300 text-sm font-medium mb-2">
            Loading climbing journal...
          </div>
          <p className="b-muted text-xs">Retrieving send details</p>
        </div>
      </div>
    );
  }

  if (!entry) {
    return (
      <div className="b-page" role="region" aria-labelledby="share-not-found-heading">
        <div className="b-page-header">
          <Link href="/app/profile" className="b-button b-button-ghost">
            <ArrowLeftIcon />
            Back to Profile
          </Link>
          <span className="b-eyebrow">Result Not Found</span>
        </div>
        <div className="b-panel b-stack">
          <h1 id="share-not-found-heading" className="b-serif text-2xl font-bold">
            Entry not found
          </h1>
          <p className="b-muted">
            The journal entry with id &quot;{entryId}&quot; could not be located.
          </p>
          <div className="b-inline">
            <Link href="/app/profile" className="b-button b-button-primary">
              Return to Profile
            </Link>
          </div>
        </div>
      </div>
    );
  }

  // Enforce invariant: Only sent attempts can be published
  if (entry.outcome !== 'sent') {
    return (
      <div className="b-page" role="region" aria-labelledby="share-unsent-heading">
        <div className="b-page-header">
          <Link href={`/app/attempt/${entry.id}`} className="b-button b-button-ghost">
            <ArrowLeftIcon />
            Back to Attempt
          </Link>
          <span className="b-eyebrow">Send Required</span>
        </div>
        <div className="b-panel b-stack">
          <h1 id="share-unsent-heading" className="b-serif text-2xl font-bold">
            Climb not marked as sent
          </h1>
          <p className="b-muted">
            This entry is currently recorded as an attempt. In Boarded, only clean sends can be
            published to the community or exported as milestone result cards.
          </p>
          <div className="b-inline">
            <Link href={`/app/attempt/${entry.id}`} className="b-button b-button-primary">
              View Attempt & Mark as Sent →
            </Link>
            <Link href="/app/profile" className="b-button">
              View Profile
            </Link>
          </div>
        </div>
      </div>
    );
  }

  const handlePublish = (e: React.FormEvent) => {
    e.preventDefault();
    setPublishStatus(null);
    setPublishError(null);

    if (caption.length > 280) {
      setPublishError('Caption must be 280 characters or fewer before publishing.');
      return;
    }

    const res = publish(entry.id, caption);
    if ('error' in res) {
      setPublishError(res.error);
    } else {
      setPublishStatus(
        entry.published
          ? 'Send caption updated successfully in your local journal!'
          : 'Send published successfully to local journal and profile!'
      );
    }
  };

  const directShareUrl =
    typeof window !== 'undefined'
      ? `${window.location.origin}/app/send/${entry.id}`
      : `/app/send/${entry.id}`;

  const handleCopyLink = async () => {
    setCopySuccess(null);
    setCopyError(null);
    try {
      if (typeof navigator !== 'undefined' && navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(directShareUrl);
        setCopySuccess('Direct climb link copied to clipboard.');
        setManualCopyUrl(null);
      } else {
        throw new Error('Clipboard unavailable.');
      }
    } catch {
      setCopyError('Could not write to clipboard. Select and copy the URL below:');
      setManualCopyUrl(directShareUrl);
    }
  };

  // Construct self-contained, downloadable SVG result card
  function toSafeXml(str: string): string {
    if (!str) return '';
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  // Unicode-safe word and grapheme wrapping to avoid splitting surrogate pairs or emojis
  function wrapTextUnicode(text: string, maxCharsPerLine = 56): string[] {
    if (!text) return [];
    const words = text.split(' ');
    const lines: string[] = [];
    let currentLine = '';

    const getLength = (str: string): number => {
      if (typeof Intl !== 'undefined' && Intl.Segmenter) {
        const seg = new Intl.Segmenter('en', { granularity: 'grapheme' });
        return Array.from(seg.segment(str)).length;
      }
      return Array.from(str).length;
    };

    const splitLongWord = (word: string): string[] => {
      const parts: string[] = [];
      let chars: string[];
      if (typeof Intl !== 'undefined' && Intl.Segmenter) {
        const seg = new Intl.Segmenter('en', { granularity: 'grapheme' });
        chars = Array.from(seg.segment(word), (s) => s.segment);
      } else {
        chars = Array.from(word);
      }
      while (chars.length > maxCharsPerLine) {
        parts.push(chars.splice(0, maxCharsPerLine).join(''));
      }
      if (chars.length > 0) {
        parts.push(chars.join(''));
      }
      return parts;
    };

    for (const word of words) {
      if (!currentLine) {
        if (getLength(word) > maxCharsPerLine) {
          const parts = splitLongWord(word);
          lines.push(...parts.slice(0, -1));
          currentLine = parts[parts.length - 1] || '';
        } else {
          currentLine = word;
        }
      } else {
        const candidate = `${currentLine} ${word}`;
        if (getLength(candidate) <= maxCharsPerLine) {
          currentLine = candidate;
        } else {
          lines.push(currentLine);
          if (getLength(word) > maxCharsPerLine) {
            const parts = splitLongWord(word);
            lines.push(...parts.slice(0, -1));
            currentLine = parts[parts.length - 1] || '';
          } else {
            currentLine = word;
          }
        }
      }
    }

    if (currentLine) {
      lines.push(currentLine);
    }

    return lines;
  }

  const hasCaption = Boolean(caption && caption.trim().length > 0);
  const captionLines = hasCaption ? wrapTextUnicode(caption, 56) : [];
  const formattedCaptionLines = captionLines.map((line, idx) => {
    const isFirst = idx === 0;
    const isLast = idx === captionLines.length - 1;
    const prefix = isFirst ? '&#x201C;' : '';
    const suffix = isLast ? '&#x201D;' : '';
    return `${prefix}${toSafeXml(line)}${suffix}`;
  });

  const captionStartY = 412;
  const captionSvgText = formattedCaptionLines
    .map((lineHtml, idx) => {
      const y = captionStartY + idx * 22;
      return `<text x="80" y="${y}" fill="#d1d5db" font-size="14" font-style="italic">${lineHtml}</text>`;
    })
    .join('\n  ');
  const captionEndY = hasCaption ? captionStartY + captionLines.length * 22 : captionStartY;
  const conditionsLines = wrapTextUnicode(entry.conditions || '', 56);
  const conditionsY = conditionsLines.length > 0 ? (hasCaption ? captionEndY + 18 : captionStartY) : 0;
  const conditionsEndY = conditionsLines.length > 0 ? conditionsY + conditionsLines.length * 18 : 0;
  const captionBoxBottom = Math.max(585, conditionsEndY + 24, hasCaption ? captionEndY + 24 : 0);
  const svgHeight = Math.max(700, captionBoxBottom + 85);
  const footerY = svgHeight - 60;
  const conditionsSvgText = conditionsLines.map((line, idx) => {
    const prefix = idx === 0 ? 'Conditions: ' : '';
    return `<text x="80" y="${conditionsY + idx * 18}" fill="#9ca3af" font-size="12">${prefix}${toSafeXml(line)}</text>`;
  }).join('\n  ');

  const handleDownload = async () => {
    setDownloadError(null);
    setDownloadState('loading');
    try {
      const response = await fetch('/fonts/CormorantGaramond-SemiBoldItalic.ttf');
      if (!response.ok) {
        throw new Error(`Font request failed (${response.status})`);
      }
      const fontBlob = await response.blob();
      const fontDataUrl = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
          if (typeof reader.result === 'string') resolve(reader.result);
          else reject(new Error('Font data was not readable.'));
        };
        reader.onerror = () => reject(reader.error ?? new Error('Font data could not be read.'));
        reader.readAsDataURL(fontBlob);
      });

      const svgCardContent = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 ${svgHeight}" width="600" height="${svgHeight}" style="background:#0A0B10; font-family:system-ui,-apple-system,sans-serif;">
  <defs>
    <style><![CDATA[
      @font-face {
        font-family: 'CormorantGaramond';
        font-style: italic;
        font-weight: 600;
        src: url('${fontDataUrl}') format('truetype');
      }
    ]]></style>
  </defs>

  <!-- Background Canvas -->
  <rect width="600" height="${svgHeight}" fill="#0A0B10" />
  <rect x="24" y="24" width="552" height="${svgHeight - 48}" rx="16" fill="#171A22" stroke="#2A2F3A" stroke-width="2" />

  <!-- Brand Mark Header -->
  <text x="56" y="70" fill="#F4F2EB" font-family="system-ui,-apple-system,sans-serif" font-size="12" font-weight="800" letter-spacing="2">BOARDED CLIMBING JOURNAL</text>
  <text x="544" y="70" fill="#32D583" font-family="system-ui,-apple-system,sans-serif" font-size="12" font-weight="700" text-anchor="end" letter-spacing="1">VERIFIED SEND</text>

  <line x1="56" y1="90" x2="544" y2="90" stroke="#3A3F4A" stroke-width="1" />

  <!-- Grade Display (Serif) -->
  <text x="56" y="150" fill="#F4F2EB" font-family="CormorantGaramond,serif" font-size="52" font-weight="600" font-style="italic">
    ${toSafeXml(route?.grade || '5.12')}
  </text>

  <!-- Route Title -->
  <text x="56" y="195" fill="#F4F2EB" font-family="CormorantGaramond,serif" font-size="28" font-weight="600" font-style="italic">
    ${toSafeXml(route?.name || entry.routeId)}
  </text>

  <!-- Crag & Attributes -->
  <text x="56" y="225" fill="#9ca3af" font-family="system-ui,-apple-system,sans-serif" font-size="14">
    ${toSafeXml(`${route?.crag || 'Outdoor Crag'} · ${route?.type || 'Sport'} · ${route?.height || '27 m'} · ${route?.rock || 'Limestone'}`)}
  </text>

  <!-- Status Shelf -->
  <rect x="56" y="255" width="488" height="68" rx="8" fill="#12141C" stroke="#2A2F3A" />
  <text x="76" y="285" fill="#9ca3af" font-family="system-ui,-apple-system,sans-serif" font-size="11" font-weight="700" letter-spacing="1">CLIMBER</text>
  <text x="76" y="307" fill="#F4F2EB" font-family="system-ui,-apple-system,sans-serif" font-size="14" font-weight="600">Alex R.</text>
  <text x="210" y="285" fill="#9ca3af" font-family="system-ui,-apple-system,sans-serif" font-size="11" font-weight="700" letter-spacing="1">ATTEMPTS</text>
  <text x="210" y="307" fill="#F4F2EB" font-family="system-ui,-apple-system,sans-serif" font-size="14" font-weight="600">${entry.attempts} tries</text>
  <text x="340" y="285" fill="#9ca3af" font-family="system-ui,-apple-system,sans-serif" font-size="11" font-weight="700" letter-spacing="1">DATE</text>
  <text x="340" y="307" fill="#F4F2EB" font-family="system-ui,-apple-system,sans-serif" font-size="14" font-weight="600">${toSafeXml(entry.date)}</text>
  <text x="470" y="285" fill="#32D583" font-family="system-ui,-apple-system,sans-serif" font-size="11" font-weight="700" letter-spacing="1">OUTCOME</text>
  <text x="470" y="307" fill="#32D583" font-family="system-ui,-apple-system,sans-serif" font-size="14" font-weight="700">SENT</text>

  <!-- Caption & Beta Notes -->
  <rect x="56" y="345" width="488" height="${captionBoxBottom - 345}" rx="8" fill="#0F1118" stroke="#252A34" />
  <text x="80" y="380" fill="#F4F2EB" font-family="system-ui,-apple-system,sans-serif" font-size="13" font-weight="700">CAPTION &amp; NOTES</text>
  ${captionSvgText}
  ${conditionsSvgText}

  <!-- Footer Seal -->
  <text x="300" y="${footerY}" fill="#6b7280" font-family="system-ui,-apple-system,sans-serif" font-size="11" text-anchor="middle">
    Verified Local Record · Boarded Editorial Journal
  </text>
</svg>
`.trim();
      const svgBlob = new Blob([svgCardContent], { type: 'image/svg+xml;charset=utf-8' });
      const objectUrl = URL.createObjectURL(svgBlob);
      try {
        const link = document.createElement('a');
        link.href = objectUrl;
        link.download = `boarded-${route?.id || 'send'}-result.svg`;
        link.click();
      } finally {
        URL.revokeObjectURL(objectUrl);
      }
    } catch {
      setDownloadError('Could not load the canonical card font. Try Download Result Card again.');
    } finally {
      setDownloadState('idle');
    }
  };

  return (
    <article className="b-page" aria-labelledby="share-title">
      <div className="b-page-header">
        <Link href={`/app/attempt/${entry.id}`} className="b-button b-button-ghost">
          <ArrowLeftIcon />
          Back to Attempt
        </Link>
        <span className="b-eyebrow">Share Result Card</span>
      </div>

      <div className="b-panel b-stack">
        <div>
          <div className="b-eyebrow text-stone-400 mb-1">Send Celebration</div>
          <h1 id="share-title" className="b-serif text-3xl font-semibold italic text-stone-100">
            Publish & Export Result Card
          </h1>
          <p className="b-muted text-sm mt-1">
            Review your live climbing card preview. Local demo publish stays on this device.
          </p>
        </div>

        {/* Live HTML Result Card Preview */}
        <section aria-label="Live climbing result card preview" className="b-result-card-preview">
          <div className="b-result-card-header">
            <span className="b-result-card-brand">Boarded Climbing Journal</span>
            <span className="b-status b-status-sent text-xs">
              <CheckmarkIcon className="w-3.5 h-3.5" />
              Verified Send
            </span>
          </div>

          <div className="b-result-card-body">
            <div className="b-eyebrow text-stone-400">
              {route?.crag || 'Stonegate'} · {route?.type || 'Sport'}
            </div>
            <div className="b-serif text-4xl text-indigo-400">
              {route?.grade || '5.12a'}
            </div>
            <div className="b-serif text-2xl text-stone-100 font-semibold">
              {route?.name || entry.routeId}
            </div>

            <div className="b-facts pt-2">
              <span className="b-fact-item">
                <strong className="text-stone-300">Climber:</strong> Alex R.
              </span>
              <span className="text-stone-600" aria-hidden="true">•</span>
              <span className="b-fact-item">
                <strong className="text-stone-300">Attempts:</strong> {entry.attempts}
              </span>
              <span className="text-stone-600" aria-hidden="true">•</span>
              <span className="b-fact-item">
                <strong className="text-stone-300">Date:</strong> {entry.date}
              </span>
            </div>

            {caption.trim() ? (
              <blockquote className="b-result-card-notes">
                &ldquo;{caption}&rdquo;
              </blockquote>
            ) : null}
          </div>
        </section>

        {/* Publish Form */}
        <form onSubmit={handlePublish} className="b-stack pt-2 border-t border-stone-800">
          <div className="b-field">
            <label htmlFor="share-caption">
              Custom Send Caption (max 280 characters):
            </label>
            <textarea
              id="share-caption"
              rows={3}
              maxLength={280}
              value={caption}
              onChange={(e) => {
                isUserEditedRef.current = true;
                setCaption(e.target.value);
              }}
              placeholder="Add your reflections on sticking the crux or finding beta..."
              className="resize-y"
            />
            <div className="flex justify-between items-center text-xs text-stone-400">
              <span>Plainly stored: Local demo publish stays on this device.</span>
              <span>{caption.length} / 280</span>
            </div>
          </div>
          {publishError && (
            <div role="alert" className="b-errors p-3 bg-red-950/50 border border-red-500 rounded">
              {publishError}
            </div>
          )}

          {publishStatus && (
            <div role="status" aria-live="polite" className="p-3 bg-emerald-950/60 border border-emerald-500 rounded-md text-emerald-300 text-sm flex items-center justify-between flex-wrap gap-2">
              <div className="flex items-center gap-2">
                <CheckmarkIcon className="w-4 h-4 text-emerald-400" />
                <span>{publishStatus}</span>
              </div>
              <div className="b-inline">
                <Link href="/app" className="b-button b-button-ghost text-xs">
                  View Feed →
                </Link>
                <Link href="/app/profile" className="b-button b-button-ghost text-xs">
                  View Profile →
                </Link>
              </div>
            </div>
          )}

          <div className="b-inline pt-2">
            <button
              type="submit"
              disabled={entry.published && entry.caption === caption}
              className="b-button b-button-primary"
            >
              <CheckmarkIcon />
              {!entry.published
                ? 'Publish Result Card'
                : entry.caption === caption
                ? 'Published to Journal'
                : 'Update Published Caption'}
            </button>

            {/* Downloadable self-contained SVG graphic */}
            <button
              type="button"
              onClick={handleDownload}
              disabled={downloadState === 'loading'}
              className="b-button min-h-[44px]"
            >
              <DownloadIcon />
              {downloadState === 'loading' ? 'Preparing Result Card…' : 'Download Result Card (SVG)'}
            </button>
            {downloadError && (
              <div role="alert" className="basis-full text-xs text-amber-400 font-medium">
                {downloadError}
              </div>
            )}
          </div>
        </form>

        {/* Friend Share link section */}
        <section className="b-shelf b-stack mt-2" aria-labelledby="friend-share-heading">
          <h2 id="friend-share-heading" className="text-base font-semibold text-stone-200">
            Share Link with Climbing Partner
          </h2>
          <p className="b-muted text-xs">
            Send a direct link to your partner so they can inspect your send metrics.
          </p>

          {copySuccess && (
            <div role="status" aria-live="polite" className="text-xs text-emerald-400 font-medium">
              {copySuccess}
            </div>
          )}

          {copyError && (
            <div role="alert" className="text-xs text-amber-400 font-medium">
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
                className="w-full text-xs font-mono bg-stone-900 border border-stone-700 p-2 rounded text-stone-200 min-h-[44px]"
              />
            </div>
          )}

          <div>
            <button
              type="button"
              onClick={handleCopyLink}
              className="b-button"
            >
              <CopyIcon />
              Copy Direct Send URL
            </button>
          </div>
        </section>
      </div>
    </article>
  );
}

/* ==========================================================================
   3. Profile Screen Component (/app/profile)
   ========================================================================== */

export function ProfileScreen() {
  const {
    entries,
    savedRouteIds,
    toggleSave,
    deleteEntry,
    restoreEntry,
    followingMaya,
    setFollowing,
  } = useJournal();

  const [activeTab, setActiveTab] = useState<'entries' | 'saved'>('entries');

  // Deletion dialog states
  const [entryToDelete, setEntryToDelete] = useState<Entry | null>(null);
  const deleteTriggerBtnRef = useRef<HTMLButtonElement | null>(null);
  const undoButtonRef = useRef<HTMLButtonElement | null>(null);
  const justConfirmedRef = useRef(false);
  const profileRootRef = useRef<HTMLElement | null>(null);
  const [portalContainer, setPortalContainer] = useState<HTMLElement | null>(null);

  useEffect(() => {
    setPortalContainer(profileRootRef.current);
  }, []);

  // Undo persistent action state
  const [lastDeletedEntry, setLastDeletedEntry] = useState<Entry | null>(null);
  const [undoNotice, setUndoNotice] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const handleDeleteConfirm = () => {
    if (!entryToDelete) return;
    const target = entryToDelete;
    const routeName = routes.find((r) => r.id === target.routeId)?.name || target.routeId;
    setDeleteError(null);
    const res = deleteEntry(target.id);
    if ('error' in res) {
      justConfirmedRef.current = false;
      setDeleteError(`Could not delete entry for "${routeName}": ${res.error}`);
      return;
    }
    justConfirmedRef.current = true;
    setDeleteError(null);
    setLastDeletedEntry(target);
    setUndoNotice(`Entry for "${routeName}" deleted.`);
    setEntryToDelete(null);
  };

  const handleUndo = () => {
    if (!lastDeletedEntry) return;
    const target = lastDeletedEntry;
    const res = restoreEntry(target);
    if ('error' in res) {
      setUndoNotice(`Could not restore entry: ${res.error}`);
    } else {
      setUndoNotice(null);
      setLastDeletedEntry(null);
      setTimeout(() => {
        document.getElementById(`delete-entry-${target.id}`)?.focus();
      }, 50);
    }
  };

  // Honest statistics computed from actual journal entries
  const totalSessions = entries.length;
  const totalAttempts = entries.reduce((sum, e) => sum + e.attempts, 0);
  const totalSends = entries.filter((e) => e.outcome === 'sent').length;
  const publishedSends = entries.filter((e) => e.published).length;

  // Saved routes
  const savedRoutes = routes.filter((r) => savedRouteIds.includes(r.id));

  return (
    <article ref={profileRootRef} className="b-page" aria-labelledby="profile-heading">
      <div className="b-page-header">
        <span className="b-eyebrow">Climber Profile</span>
        <Link href="/app" className="b-button b-button-ghost">
          Back to Feed
        </Link>
      </div>
      {/* Climber Identity Card */}
      <header className="b-panel b-stack">
        <div className="flex items-start justify-between flex-wrap gap-4">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-full bg-slate-800 border-2 border-indigo-500/50 flex items-center justify-center font-bold text-xl text-stone-100">
              AR
            </div>
            <div>
              <h1 id="profile-heading" className="text-2xl font-bold text-stone-100">
                Alex R.
              </h1>
              <p className="text-xs text-stone-400 mt-0.5">
                Local Journal Climber · Home Crag: Stonegate
              </p>
            </div>
          </div>

          <div className="b-inline">
            <button
              type="button"
              onClick={() => setFollowing(!followingMaya)}
              aria-pressed={followingMaya}
              className={`b-button ${followingMaya ? 'b-button-ghost' : 'b-button-primary'}`}
            >
              {followingMaya ? 'Following Maya K.' : '+ Follow Maya K.'}
            </button>
            <Link href="/app/log" className="b-button b-button-primary">
              + Log Session
            </Link>
          </div>
        </div>

        {/* Honest Stats Grid */}
        <div className="b-stats-grid pt-2">
          <div className="b-stat-card">
            <span className="b-stat-value">{totalSessions}</span>
            <span className="b-stat-label">Sessions</span>
          </div>
          <div className="b-stat-card">
            <span className="b-stat-value">{totalAttempts}</span>
            <span className="b-stat-label">Total Attempts</span>
          </div>
          <div className="b-stat-card">
            <span className="b-stat-value">{totalSends}</span>
            <span className="b-stat-label">Verified Sends</span>
          </div>
          <div className="b-stat-card">
            <span className="b-stat-value">{publishedSends}</span>
            <span className="b-stat-label">Published</span>
          </div>
        </div>
      </header>

      {/* Persistent Undo Banner */}
      {undoNotice && (
        <div role="status" aria-live="polite" className="b-undo-banner">
          <span>{undoNotice}</span>
          <button
            type="button"
            ref={undoButtonRef}
            onClick={handleUndo}
            className="b-button b-button-primary text-xs px-3 py-1.5 min-h-0"
          >
            Undo Deletion
          </button>
        </div>
      )}

      {/* Section filters for My Entries and Saved Routes */}
      <section className="b-stack">
        <div className="flex border-b border-stone-800 gap-4" role="group" aria-label="Journal sections">
          <button
            type="button"
            aria-pressed={activeTab === 'entries'}
            onClick={() => setActiveTab('entries')}
            className={`pb-3 min-h-[44px] text-sm font-semibold border-b-2 transition-colors ${
              activeTab === 'entries'
                ? 'border-indigo-500 text-stone-100'
                : 'border-transparent text-stone-400 hover:text-stone-200'
            }`}
          >
            My Journal Entries ({entries.length})
          </button>
          <button
            type="button"
            aria-pressed={activeTab === 'saved'}
            onClick={() => setActiveTab('saved')}
            className={`pb-3 min-h-[44px] text-sm font-semibold border-b-2 transition-colors ${
              activeTab === 'saved'
                ? 'border-indigo-500 text-stone-100'
                : 'border-transparent text-stone-400 hover:text-stone-200'
            }`}
          >
            Saved Routes ({savedRouteIds.length})
          </button>
        </div>

        {/* Journal entries section */}
        {activeTab === 'entries' && (
          <div className="b-stack">
            {entries.length === 0 ? (
              <div className="b-panel text-center py-8">
                <p className="text-stone-300 font-medium">Your journal has no recorded attempts.</p>
                <p className="text-xs text-stone-400 mt-1 mb-4">
                  Log your tries, tick your projects, and build your climbing history.
                </p>
                <Link href="/app/log" className="b-button b-button-primary">
                  Log your first attempt
                </Link>
              </div>
            ) : (
              entries.map((entry) => {
                const route = routes.find((r) => r.id === entry.routeId);
                const isSent = entry.outcome === 'sent';
                return (
                  <div key={entry.id} className="b-panel b-stack">
                    <div className="flex items-start justify-between flex-wrap gap-2">
                      <div>
                        <div className="b-eyebrow text-stone-400 mb-0.5">{entry.date}</div>
                        <h2 className="text-xl font-semibold text-stone-100">
                          <span className="b-serif text-indigo-400 mr-2">{route?.grade || '5.12'}</span>
                          <Link href={`/app/route/${entry.routeId}`} className="b-serif hover:underline inline-flex items-center min-h-[44px]">
                            {route?.name || entry.routeId}
                          </Link>
                        </h2>
                      </div>

                      <div className="b-inline">
                        <span className={`b-status ${isSent ? 'b-status-sent' : 'b-status-attempt'}`}>
                          {isSent ? 'Sent' : 'Attempted'}
                        </span>
                        <span className="b-status">
                          {entry.published ? 'Published' : 'Private'}
                        </span>
                      </div>
                    </div>

                    <div className="b-shelf">
                      <div className="b-facts">
                        <span className="b-fact-item">
                          <strong className="text-stone-300">Attempts:</strong> {entry.attempts}
                        </span>
                        {route && (
                          <>
                            <span className="text-stone-600" aria-hidden="true">•</span>
                            <span className="b-fact-item">
                              <strong className="text-stone-300">Crag:</strong> {route.crag}
                            </span>
                            <span className="text-stone-600" aria-hidden="true">•</span>
                            <span className="b-fact-item">
                              <strong className="text-stone-300">Rock:</strong> {route.rock}
                            </span>
                          </>
                        )}
                      </div>
                      {entry.notes && (
                        <p className="text-xs text-stone-300 italic mt-2 m-0">
                          &ldquo;{entry.notes}&rdquo;
                        </p>
                      )}
                    </div>

                    <div className="b-inline justify-between pt-2 border-t border-stone-800">
                      <div className="b-inline">
                        <Link href={`/app/attempt/${entry.id}`} className="b-button b-button-ghost text-xs">
                          View Attempt Details
                        </Link>
                        {isSent && (
                          <Link href={`/app/share/${entry.id}`} className="b-button b-button-ghost text-xs">
                            {entry.published ? 'Share Card' : 'Publish Result Card'}
                          </Link>
                        )}
                      </div>

                      <button
                        id={`delete-entry-${entry.id}`}
                        type="button"
                        onClick={(e) => {
                          deleteTriggerBtnRef.current = e.currentTarget;
                          setDeleteError(null);
                          setEntryToDelete(entry);
                        }}
                        className="b-button b-button-danger text-xs"
                        aria-label={`Delete entry for ${route?.name || entry.routeId}`}
                      >
                        <TrashIcon />
                        Delete
                      </button>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        )}

        {/* Saved routes section */}
        {activeTab === 'saved' && (
          <div className="b-stack">
            {savedRoutes.length === 0 ? (
              <div className="b-panel text-center py-8">
                <p className="text-stone-300 font-medium">No saved routes in your wishlist.</p>
                <p className="text-xs text-stone-400 mt-1 mb-4">
                  Browse the crag directory and bookmark routes you want to project.
                </p>
                <Link href="/app/explore" className="b-button b-button-primary">
                  Explore Routes
                </Link>
              </div>
            ) : (
              savedRoutes.map((r) => (
                <div key={r.id} className="b-panel flex items-center justify-between flex-wrap gap-3">
                  <div>
                    <div className="b-eyebrow text-stone-400 mb-0.5">
                      {r.crag} · {r.type} · {r.height}
                    </div>
                    <h2 className="text-xl font-semibold text-stone-100">
                      <span className="b-serif text-indigo-400 mr-2">{r.grade}</span>
                      <Link href={`/app/route/${r.id}`} className="b-serif hover:underline inline-flex items-center min-h-[44px]">
                        {r.name}
                      </Link>
                    </h2>
                    <p className="text-xs text-stone-400 mt-1 max-w-lg">{r.description}</p>
                  </div>
                  <div className="b-inline">
                    <Link href={`/app/log?route=${r.id}`} className="b-button b-button-primary text-xs">
                      Log Attempt
                    </Link>
                    <button
                      type="button"
                      onClick={() => toggleSave(r.id)}
                      className="b-button b-button-ghost text-xs"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        )}
      </section>

      {/* Radix Accessible Deletion Confirmation Dialog */}
      <Dialog.Root
        open={Boolean(entryToDelete)}
        onOpenChange={(open) => {
          if (!open) {
            setDeleteError(null);
            setEntryToDelete(null);
          }
        }}
      >
        <Dialog.Portal container={portalContainer}>
          <Dialog.Overlay className="b-modal-overlay" />
          <Dialog.Content
            className="b-modal-dialog"
            onCloseAutoFocus={(e) => {
              if (justConfirmedRef.current) {
                e.preventDefault();
                justConfirmedRef.current = false;
                setTimeout(() => {
                  undoButtonRef.current?.focus();
                }, 50);
              } else {
                e.preventDefault();
                deleteTriggerBtnRef.current?.focus();
              }
            }}
          >
            <Dialog.Title className="b-modal-title">
              Delete journal entry?
            </Dialog.Title>
            <Dialog.Description className="b-modal-body">
              Are you sure you want to remove this attempt on &ldquo;
              {entryToDelete
                ? routes.find((r) => r.id === entryToDelete.routeId)?.name || entryToDelete.routeId
                : 'this climb'}
              &rdquo; from {entryToDelete?.date}? You can undo this action immediately after deleting.
            </Dialog.Description>
            {deleteError && (
              <div role="alert" className="b-errors">
                {deleteError}
              </div>
            )}
            <div className="b-modal-actions">
              <Dialog.Close asChild>
                <button type="button" className="b-button b-button-ghost">
                  Cancel
                </button>
              </Dialog.Close>
              <button
                type="button"
                onClick={handleDeleteConfirm}
                className="b-button b-button-danger"
              >
                Confirm Delete
              </button>
            </div>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
    </article>
  );
}
