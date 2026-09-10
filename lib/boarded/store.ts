'use client';

import { create } from 'zustand';
import {
  type Entry,
  type AttemptInput,
  type Comment,
  type JournalData,
  INITIAL_JOURNAL_DATA,
  INITIAL_COMMENTS,
  routes,
  validateAttempt,
  sanitizeText,
} from './journal.ts';

export const STORAGE_KEY = 'boarded-web-journal';

export interface JournalStoreState {
  entries: Entry[];
  savedRouteIds: string[];
  likedPostIds: string[];
  comments: Comment[];
  followingMaya: boolean;
  activityRead: boolean;
  ready: boolean;
  error: string | null;
  storageCorrupted?: boolean;
  storageHydrated?: boolean;

  initialize: () => void;
  retryStorage: () => void;
  recordAttempt: (input: AttemptInput) => { id: string } | { error: string };
  markSent: (id: string) => { ok: true } | { error: string };
  publish: (id: string, caption: string) => { ok: true } | { error: string };
  toggleSave: (routeId: string) => { ok: true } | { error: string };
  toggleLike: (postId: string) => { ok: true } | { error: string };
  addComment: (postId: string, text: string) => { ok: true } | { error: string };
  setFollowing: (value: boolean) => { ok: true } | { error: string };
  markActivityRead: () => { ok: true } | { error: string };
  deleteEntry: (id: string) => { ok: true } | { error: string };
  restoreEntry: (entry: Entry) => { ok: true } | { error: string };
}

const SAFE_ID_REGEX = /^[a-zA-Z0-9_.~-]+$/;

/**
 * Validates and sanitizes untrusted data parsed from localStorage.
 * Strictly checks ALL Entry fields without destructive coercion or truncation.
 * Returns null if data is fatally corrupted or structurally invalid.
 */
export function validateAndSanitizeData(data: unknown): JournalData | null {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return null;
  }

  const obj = data as Record<string, unknown>;

  if (!Array.isArray(obj.entries)) {
    return null;
  }

  const entries: Entry[] = [];
  for (const item of obj.entries) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      return null;
    }
    const entryObj = item as Record<string, unknown>;

    // 1. id: nonempty safe URL segment
    if (
      typeof entryObj.id !== 'string' ||
      entryObj.id.length === 0 ||
      entryObj.id.length > 128 ||
      !SAFE_ID_REGEX.test(entryObj.id)
    ) {
      return null;
    }

    // 2. routeId: known route
    if (
      typeof entryObj.routeId !== 'string' ||
      !routes.some((r) => r.id === entryObj.routeId)
    ) {
      return null;
    }

    // 3. date, attempts, conditions, notes: strictly validated using validateAttempt
    if (
      typeof entryObj.date !== 'string' ||
      typeof entryObj.attempts !== 'number' ||
      !Number.isInteger(entryObj.attempts) ||
      (entryObj.conditions !== undefined && typeof entryObj.conditions !== 'string') ||
      (entryObj.notes !== undefined && typeof entryObj.notes !== 'string')
    ) {
      return null;
    }

    const conditions = typeof entryObj.conditions === 'string' ? entryObj.conditions : '';
    const notes = typeof entryObj.notes === 'string' ? entryObj.notes : '';

    // 4. outcome: explicit union
    if (entryObj.outcome !== 'attempted' && entryObj.outcome !== 'sent') {
      return null;
    }

    // 5. published: strict boolean
    if (typeof entryObj.published !== 'boolean') {
      return null;
    }

    // 6. published implies sent
    if (entryObj.published && entryObj.outcome !== 'sent') {
      return null;
    }

    // 7. caption: string <= 280
    if (
      entryObj.caption !== undefined &&
      (typeof entryObj.caption !== 'string' || entryObj.caption.length > 280)
    ) {
      return null;
    }
    const caption = typeof entryObj.caption === 'string' ? entryObj.caption : '';

    // Preserve accepted fields exactly without truncation or loss
    const entry: Entry = {
      id: entryObj.id,
      routeId: entryObj.routeId,
      date: entryObj.date,
      attempts: entryObj.attempts,
      conditions,
      notes,
      outcome: entryObj.outcome,
      published: entryObj.published,
      caption,
    };
    const attemptErrors = validateAttempt(entry);
    if (Object.keys(attemptErrors).length > 0) {
      return null;
    }

    entries.push(entry);
  }

  const savedRouteIds: string[] = [];
  if (obj.savedRouteIds !== undefined) {
    if (!Array.isArray(obj.savedRouteIds)) return null;
    for (const r of obj.savedRouteIds) {
      if (typeof r !== 'string' || !r.trim()) return null;
      savedRouteIds.push(r);
    }
  }

  const likedPostIds: string[] = [];
  if (obj.likedPostIds !== undefined) {
    if (!Array.isArray(obj.likedPostIds)) return null;
    for (const p of obj.likedPostIds) {
      if (typeof p !== 'string' || !p.trim()) return null;
      likedPostIds.push(p);
    }
  }

  const comments: Comment[] = [];
  if (obj.comments !== undefined) {
    if (!Array.isArray(obj.comments)) return null;
    for (const c of obj.comments) {
      if (!c || typeof c !== 'object' || Array.isArray(c)) return null;
      const cObj = c as Record<string, unknown>;
      if (typeof cObj.id !== 'string' || !cObj.id.trim()) return null;
      if (typeof cObj.postId !== 'string' || !cObj.postId.trim()) return null;
      if (typeof cObj.text !== 'string' || cObj.text.length > 500) return null;
      if (typeof cObj.author !== 'string' || !cObj.author.trim()) return null;
      if (cObj.createdAt !== undefined && typeof cObj.createdAt !== 'string') return null;
      comments.push({
        id: cObj.id,
        postId: cObj.postId,
        text: cObj.text,
        author: cObj.author,
        createdAt: cObj.createdAt,
      });
    }
  }

  if (obj.followingMaya !== undefined && typeof obj.followingMaya !== 'boolean') {
    return null;
  }
  const followingMaya = typeof obj.followingMaya === 'boolean' ? obj.followingMaya : true;

  if (obj.activityRead !== undefined && typeof obj.activityRead !== 'boolean') {
    return null;
  }
  const activityRead = typeof obj.activityRead === 'boolean' ? obj.activityRead : false;

  return {
    entries,
    savedRouteIds,
    likedPostIds,
    comments: obj.comments !== undefined ? comments : INITIAL_COMMENTS,
    followingMaya,
    activityRead,
  };
}

function persistToStorage(data: JournalData): { ok: true } | { error: string } {
  try {
    if (typeof window === 'undefined') {
      return { error: 'localStorage is unavailable in current runtime.' };
    }
    let storage: Storage | null = null;
    try {
      storage = window.localStorage;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      return { error: `Storage access error: ${message}` };
    }
    if (!storage) {
      return { error: 'localStorage is unavailable in current runtime.' };
    }
    const serialized = JSON.stringify(data);
    storage.setItem(STORAGE_KEY, serialized);
    return { ok: true };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return { error: `Storage write failed: ${message}` };
  }
}

function applyUpdate(
  set: (partial: Partial<JournalStoreState>) => void,
  get: () => JournalStoreState,
  partialData: Partial<JournalData>
): { ok: true } | { error: string } {
  const current = get();

  if (current.storageCorrupted) {
    return {
      error: 'Cannot modify journal while storage contains corrupted data. Preserving existing storage without resetting.',
    };
  }

  if (!current.storageHydrated) {
    return {
      error: 'Cannot modify journal before storage is safely loaded. Preserving unread storage.',
    };
  }

  const nextData: JournalData = {
    entries: partialData.entries ?? current.entries,
    savedRouteIds: partialData.savedRouteIds ?? current.savedRouteIds,
    likedPostIds: partialData.likedPostIds ?? current.likedPostIds,
    comments: partialData.comments ?? current.comments,
    followingMaya: partialData.followingMaya ?? current.followingMaya,
    activityRead: partialData.activityRead ?? current.activityRead,
  };

  // Persist next snapshot FIRST
  const persistRes = persistToStorage(nextData);
  if ('error' in persistRes) {
    set({ error: persistRes.error });
    return { error: persistRes.error };
  }

  // Commit in-memory state ONLY on success
  set({
    ...partialData,
    error: null,
  });
  return { ok: true };
}

function updateEntry(
  entries: Entry[],
  id: string,
  transform: (entry: Entry) => Entry | { error: string }
): { entries: Entry[] } | { error: string } {
  const index = entries.findIndex((e) => e.id === id);
  if (index === -1) {
    return { error: `Entry not found with id "${id}".` };
  }
  const result = transform(entries[index]);
  if ('error' in result) {
    return result;
  }
  const nextEntries = [...entries];
  nextEntries[index] = result;
  return { entries: nextEntries };
}

export const useJournal = create<JournalStoreState>((set, get) => ({
  entries: INITIAL_JOURNAL_DATA.entries,
  savedRouteIds: INITIAL_JOURNAL_DATA.savedRouteIds,
  likedPostIds: INITIAL_JOURNAL_DATA.likedPostIds,
  comments: INITIAL_JOURNAL_DATA.comments,
  followingMaya: INITIAL_JOURNAL_DATA.followingMaya,
  activityRead: INITIAL_JOURNAL_DATA.activityRead,
  ready: false,
  error: null,
  storageCorrupted: false,
  storageHydrated: false,

  initialize: () => {
    if (typeof window === 'undefined') {
      set({ ready: true, error: null, storageCorrupted: false, storageHydrated: true });
      return;
    }

    try {
      let storage: Storage | null = null;
      try {
        storage = window.localStorage;
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        set({
          ready: true,
          error: `Storage access error: ${message}`,
          storageCorrupted: false,
          storageHydrated: false,
        });
        return;
      }

      if (!storage) {
        set({
          ready: true,
          error: 'Storage access error: localStorage is unavailable in current runtime.',
          storageCorrupted: false,
          storageHydrated: false,
        });
        return;
      }

      let raw: string | null = null;
      try {
        raw = storage.getItem(STORAGE_KEY);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        set({
          ready: true,
          error: `Storage access error: ${message}`,
          storageCorrupted: false,
          storageHydrated: false,
        });
        return;
      }

      if (raw === null) {
        set({
          ...INITIAL_JOURNAL_DATA,
          ready: true,
          error: null,
          storageCorrupted: false,
          storageHydrated: true,
        });
        return;
      }

      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch {
        // Malformed JSON: do not overwrite! Retain in-memory defaults and surface recoverable error.
        set({
          ready: true,
          error: 'Stored journal data is malformed JSON. Preserving existing storage without resetting.',
          storageCorrupted: true,
          storageHydrated: false,
        });
        return;
      }

      const validated = validateAndSanitizeData(parsed);
      if (!validated) {
        // Corrupted shape: do not overwrite!
        set({
          ready: true,
          error: 'Stored journal data has an invalid schema. Preserving existing storage without resetting.',
          storageCorrupted: true,
          storageHydrated: false,
        });
        return;
      }

      set({
        entries: validated.entries,
        savedRouteIds: validated.savedRouteIds,
        likedPostIds: validated.likedPostIds,
        comments: validated.comments,
        followingMaya: validated.followingMaya,
        activityRead: validated.activityRead,
        ready: true,
        error: null,
        storageCorrupted: false,
        storageHydrated: true,
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      set({
        ready: true,
        error: `Storage access error: ${message}`,
        storageCorrupted: false,
        storageHydrated: false,
      });
    }
  },

  retryStorage: () => {
    if (typeof window === 'undefined') {
      set({ error: null, storageHydrated: true });
      return;
    }

    let storage: Storage | null = null;
    try {
      storage = window.localStorage;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      set({ error: `Storage access error: ${message}`, storageHydrated: false });
      return;
    }

    if (!storage) {
      set({ error: 'Storage access error: localStorage is unavailable in current runtime.', storageHydrated: false });
      return;
    }

    try {
      let raw: string | null = null;
      try {
        raw = storage.getItem(STORAGE_KEY);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        set({ error: `Storage access error: ${message}`, storageHydrated: false });
        return;
      }

      if (raw === null) {
        set({
          ...INITIAL_JOURNAL_DATA,
          error: null,
          storageCorrupted: false,
          storageHydrated: true,
        });
        return;
      }

      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch {
        set({
          error: 'Stored journal data is malformed JSON. Preserving existing storage without resetting.',
          storageCorrupted: true,
          storageHydrated: false,
        });
        return;
      }

      const validated = validateAndSanitizeData(parsed);
      if (!validated) {
        set({
          error: 'Stored journal data has an invalid schema. Preserving existing storage without resetting.',
          storageCorrupted: true,
          storageHydrated: false,
        });
        return;
      }

      set({
        entries: validated.entries,
        savedRouteIds: validated.savedRouteIds,
        likedPostIds: validated.likedPostIds,
        comments: validated.comments,
        followingMaya: validated.followingMaya,
        activityRead: validated.activityRead,
        error: null,
        storageCorrupted: false,
        storageHydrated: true,
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      set({ error: `Retry failed: ${message}`, storageHydrated: false });
    }
  },

  recordAttempt: (input: AttemptInput) => {
    const errors = validateAttempt(input);
    if (Object.keys(errors).length > 0) {
      const msg = Object.entries(errors)
        .map(([k, v]) => `${k}: ${v}`)
        .join('; ');
      return { error: msg };
    }

    const id = `entry-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const newEntry: Entry = {
      id,
      routeId: input.routeId,
      date: input.date,
      attempts: input.attempts,
      conditions: sanitizeText(input.conditions, 500),
      notes: sanitizeText(input.notes, 1000),
      outcome: 'attempted',
      published: false,
      caption: '',
    };

    const nextEntries = [newEntry, ...get().entries];
    const updateResult = applyUpdate(set, get, { entries: nextEntries });
    if ('error' in updateResult) {
      return { error: updateResult.error };
    }

    return { id };
  },

  markSent: (id: string) => {
    const updateRes = updateEntry(get().entries, id, (entry) => {
      if (entry.outcome === 'sent') {
        return entry; // Idempotent: already sent
      }
      return { ...entry, outcome: 'sent' };
    });

    if ('error' in updateRes) {
      return { error: updateRes.error };
    }

    return applyUpdate(set, get, { entries: updateRes.entries });
  },

  publish: (id: string, caption: string) => {
    const cleanCaption = sanitizeText(caption, 280);
    const updateRes = updateEntry(get().entries, id, (entry) => {
      if (entry.outcome !== 'sent') {
        return { error: 'Cannot publish an attempt that has not been sent.' };
      }
      if (entry.published && entry.caption === cleanCaption) {
        return entry; // Idempotent: already published with matching caption
      }
      return { ...entry, published: true, caption: cleanCaption };
    });

    if ('error' in updateRes) {
      return { error: updateRes.error };
    }

    return applyUpdate(set, get, { entries: updateRes.entries });
  },

  toggleSave: (routeId: string) => {
    if (!routeId || typeof routeId !== 'string') {
      return { error: 'Route ID is required.' };
    }

    const currentSaved = get().savedRouteIds;
    const exists = currentSaved.includes(routeId);
    const nextSaved = exists
      ? currentSaved.filter((id) => id !== routeId)
      : [...currentSaved, routeId];

    return applyUpdate(set, get, { savedRouteIds: nextSaved });
  },

  toggleLike: (postId: string) => {
    if (!postId || typeof postId !== 'string') {
      return { error: 'Post ID is required.' };
    }

    const currentLiked = get().likedPostIds;
    const exists = currentLiked.includes(postId);
    const nextLiked = exists
      ? currentLiked.filter((id) => id !== postId)
      : [...currentLiked, postId];

    return applyUpdate(set, get, { likedPostIds: nextLiked });
  },

  addComment: (postId: string, text: string) => {
    if (!postId || typeof postId !== 'string') {
      return { error: 'Post ID is required.' };
    }

    const cleanText = sanitizeText(text, 500);
    if (!cleanText) {
      return { error: 'Comment text cannot be empty.' };
    }

    const id = `comment-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const newComment: Comment = {
      id,
      postId,
      text: cleanText,
      author: 'Alex R.',
      createdAt: new Date().toISOString(),
    };

    const nextComments = [...get().comments, newComment];
    return applyUpdate(set, get, { comments: nextComments });
  },

  setFollowing: (value: boolean) => {
    return applyUpdate(set, get, { followingMaya: Boolean(value) });
  },

  markActivityRead: () => {
    return applyUpdate(set, get, { activityRead: true });
  },

  deleteEntry: (id: string) => {
    const entries = get().entries;
    const exists = entries.some((e) => e.id === id);
    if (!exists) {
      return { error: `Entry not found with id "${id}".` };
    }

    const nextEntries = entries.filter((e) => e.id !== id);
    return applyUpdate(set, get, { entries: nextEntries });
  },

  restoreEntry: (entry: Entry) => {
    if (!entry || typeof entry !== 'object' || !entry.id) {
      return { error: 'Invalid entry object for restoration.' };
    }

    const currentEntries = get().entries;
    if (currentEntries.some((e) => e.id === entry.id)) {
      // Idempotent: already present
      return { ok: true };
    }

    const outcome = entry.outcome === 'sent' ? 'sent' : 'attempted';
    const published = outcome === 'sent' ? Boolean(entry.published) : false;

    const safeEntry: Entry = {
      id: entry.id,
      routeId: entry.routeId,
      date: entry.date,
      attempts: entry.attempts,
      conditions: typeof entry.conditions === 'string' ? entry.conditions : '',
      notes: typeof entry.notes === 'string' ? entry.notes : '',
      outcome,
      published,
      caption: typeof entry.caption === 'string' ? entry.caption : '',
    };

    const nextEntries = [safeEntry, ...currentEntries];
    return applyUpdate(set, get, { entries: nextEntries });
  },
}));
