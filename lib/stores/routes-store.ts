'use client';

import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { resourceAPI, ResourceError } from '@/lib/api/client';
import type { Route, Ascent, Comment } from '@boarded/shared/types';
import { canonicalizeGrade, normalizeRouteGrades } from '@boarded/shared/utils/grades';
import { nanoid } from 'nanoid';

interface RoutesState {
  routes: Route[];
  isLoading: boolean;
  isOfflineMode: boolean;
  addRoute: (route: Route) => Promise<boolean>;
  updateRoute: (id: string, updates: Partial<Route>) => Promise<boolean>;
  deleteRoute: (id: string) => Promise<boolean>;
  addAscent: (routeId: string, ascent: Ascent) => Promise<boolean>;
  hasUserClimbed: (routeId: string, userId: string) => boolean;
  addComment: (routeId: string, comment: Comment) => Promise<boolean>;
  deleteComment: (routeId: string, commentId: string) => Promise<boolean>;
  incrementViewCount: (routeId: string) => Promise<void>;
  toggleLike: (routeId: string, userId: string) => Promise<boolean>;
  isLikedByUser: (routeId: string, userId: string) => boolean;
  getLikeCount: (routeId: string) => number;
  fetchRoutes: () => Promise<void>;
  fetchRouteById: (id: string) => Promise<Route | null>;
  syncLocalRoutes: () => Promise<void>;
  clearRemoteRoutes: (currentUserId?: string) => void;
}

type LocalRoute = Route & { _socialSyncPending?: boolean; _createSyncPending?: boolean; _deletedCommentIds?: string[] };
let routeFetchGeneration = 0;
let routeSyncGeneration = 0;
let routeAuthGeneration = 0;
let routeSyncLock = Promise.resolve();
const routeMutationRevisions = new Map<string, number>();
let verifiedRouteOwner: string | undefined;
let quarantinedRoutes: LocalRoute[] = [];

function routePayload(route: Partial<Route>) {
  const { id, wall_id, wall_image_url, wall_image_width, wall_image_height, name, description, grade_v, grade_font, rating, holds, is_public, share_token } = route;
  return { id, wall_id, wall_image_url, wall_image_width, wall_image_height, name, description, grade_v, grade_font, rating, holds, is_public, share_token };
}

function ascentPayload(ascent: Ascent) {
  const { id, grade_v, rating, notes, flashed } = ascent;
  return { id, grade_v: canonicalizeGrade(grade_v), rating, notes, flashed };
}

async function normalizeRouteImage(route: Route) {
  if (!route.wall_image_url) return route.wall_image_url;
  // Snapshot bytes are copied into a route-owned file, never a wall's private URL.
  const response = await fetch(route.wall_image_url, { credentials: 'same-origin', cache: 'no-store' });
  if (!response.ok) throw new Error(`Unable to read route wall snapshot (${response.status})`);
  const uploaded = await resourceAPI.upload(await response.blob(), 'route-snapshot', { wall_id: route.wall_id, route_id: route.id });
  return uploaded.url;
}

function mergeRemoteRoute(remote: Route, existing: Route | undefined, userId?: string): LocalRoute {
  const pending = existing?.user_id === userId && remote.user_id === userId ? existing as LocalRoute : undefined;
  if (pending?._createSyncPending) return normalizeRouteGrades({ ...remote, ...pending });
  return normalizeRouteGrades({
    ...remote,
    holds: remote.holds || [],
    ascents: pending?._socialSyncPending ? pending.ascents || [] : remote.ascents || [],
    comments: pending?._socialSyncPending ? pending.comments || [] : remote.comments || [],
    _socialSyncPending: pending?._socialSyncPending,
    _createSyncPending: pending?._createSyncPending,
    _deletedCommentIds: pending?._deletedCommentIds,
  } as LocalRoute);
}

export const useRoutesStore = create<RoutesState>()(persist((set, get) => ({
  routes: [],
  isLoading: false,
  isOfflineMode: false,

  fetchRoutes: async () => {
    const generation = ++routeFetchGeneration;
    set({ isLoading: true });
    try {
      const { user } = await resourceAPI.session();
      if (generation !== routeFetchGeneration) return;
      if (user?.id !== verifiedRouteOwner) {
        set({ isLoading: false });
        return;
      }
      const remote = await resourceAPI.request<Route[]>('/api/routes');
      const { user: latest } = await resourceAPI.session();
      if (generation !== routeFetchGeneration || latest?.id !== user?.id) return;
      const existing = get().routes;
      const merged = remote.map((route) => mergeRemoteRoute(route, existing.find((item) => item.id === route.id), user?.id));
      const local = existing.filter((route: LocalRoute) => route.user_id === 'local-user' ||
        (route.user_id === user?.id && (route._createSyncPending || route._socialSyncPending)));
      set({ routes: [...merged, ...local.filter((route) => !remote.some((item) => item.id === route.id))], isLoading: false, isOfflineMode: false });
    } catch {
      if (generation === routeFetchGeneration) set({ isLoading: false, isOfflineMode: true });
    }
  },

  clearRemoteRoutes: (currentUserId) => {
    routeFetchGeneration += 1;
    routeSyncGeneration += 1;
    routeAuthGeneration += 1;
    routeMutationRevisions.clear();
    verifiedRouteOwner = currentUserId;
    set((state) => {
      const combined = new Map<string, LocalRoute>();
      for (const route of [...quarantinedRoutes, ...state.routes]) {
        combined.set(`${route.user_id}:${route.id}`, route);
      }
      const routes: Route[] = [];
      quarantinedRoutes = [];
      for (const route of combined.values()) {
        if (route.user_id === 'local-user') routes.push(route);
        else if (route._createSyncPending || route._socialSyncPending) {
          if (route.user_id === currentUserId) routes.push(route);
          else quarantinedRoutes.push(route);
        }
      }
      return { routes, isLoading: false };
    });
  },

  fetchRouteById: async (id) => {
    const generation = routeAuthGeneration;
    try {
      const { user } = await resourceAPI.session();
      if (!user || generation !== routeAuthGeneration || user.id !== verifiedRouteOwner) return null;
      const remote = await resourceAPI.request<Route>(`/api/routes/${encodeURIComponent(id)}`);
      const { user: latest } = await resourceAPI.session();
      if (generation !== routeAuthGeneration || latest?.id !== user.id) return null;
      const route = mergeRemoteRoute(remote, get().routes.find((item) => item.id === id), user.id);
      set((state) => ({ routes: state.routes.some((item) => item.id === id)
        ? state.routes.map((item) => item.id === id ? route : item) : [...state.routes, route] }));
      return route;
    } catch { return null; }
  },

  syncLocalRoutes: async () => {
    const generation = routeAuthGeneration;
    const previous = routeSyncLock;
    const { promise, resolve } = Promise.withResolvers<void>();
    routeSyncLock = promise;
    await previous;
    try {
      if (generation !== routeAuthGeneration) return;
      const syncGeneration = ++routeSyncGeneration;
      const stale = () => generation !== routeAuthGeneration || syncGeneration !== routeSyncGeneration;
      const { user } = await resourceAPI.session();
      if (!user || stale() || user.id !== verifiedRouteOwner) return;
      const localRoutes = get().routes.filter((route: LocalRoute) => route.user_id === 'local-user' ||
        (route.user_id === user.id && (route._createSyncPending || route._socialSyncPending)));
      for (const candidate of localRoutes) {
        if (stale()) return;
        // A local edit/delete while the previous record synchronized must win.
        const local = get().routes.find((route) => route.id === candidate.id) as LocalRoute | undefined;
        if (!local) continue;
        try {
          const needsParentSync = local.user_id !== user.id || Boolean(local._createSyncPending);
          const initialRevision = routeMutationRevisions.get(local.id) || 0;
          let remote: Route;
          let snapshotSource = local.wall_image_url;
          let snapshotUrl = local.wall_image_url;
          if (!needsParentSync) {
            remote = await resourceAPI.request<Route>(`/api/routes/${encodeURIComponent(local.id)}`);
          } else {
            snapshotUrl = await normalizeRouteImage(local);
            if (stale()) return;
            remote = await resourceAPI.request<Route>('/api/routes', { method: 'POST', body: JSON.stringify(routePayload({ ...local, wall_image_url: snapshotUrl })) });
          }
          if (stale()) return;
          if (remote.user_id !== user.id) throw new Error('Unable to verify route owner');
          // Claim only an owner-verified row. Keep newer local fields until a
          // PATCH acknowledges them: idempotent POST returns existing rows unchanged.
          set((state) => ({ routes: state.routes.map((route) => {
            if (route.id !== local.id) return route;
            if (needsParentSync) return { ...route, user_id: user.id, _createSyncPending: true } as LocalRoute;
            return (routeMutationRevisions.get(local.id) || 0) === initialRevision
              ? mergeRemoteRoute(remote, route, user.id) : route;
          }) }));
          while (!stale()) {
            const latest = get().routes.find((route) => route.id === local.id) as LocalRoute | undefined;
            if (!latest) {
              await resourceAPI.request(`/api/routes/${encodeURIComponent(local.id)}`, { method: 'DELETE' });
              break;
            }
            const revision = routeMutationRevisions.get(local.id) || 0;
            if (needsParentSync) {
              if (latest.wall_image_url !== snapshotSource) {
                snapshotSource = latest.wall_image_url;
                snapshotUrl = await normalizeRouteImage(latest);
                if (stale()) return;
              }
              remote = await resourceAPI.request<Route>(`/api/routes/${encodeURIComponent(local.id)}`, {
                method: 'PATCH',
                body: JSON.stringify(routePayload({ ...latest, id: undefined, wall_image_url: snapshotUrl })),
              });
              if (stale()) return;
            }
            let socialPending = false;
            const savedAscents = new Map<string, Ascent>();
            const savedComments = new Map<string, Comment>();
            const deletedComments = new Set<string>();
            for (const ascent of latest.ascents || []) {
              if (ascent.user_id !== 'local-user' && ascent.user_id !== user.id) continue;
              try {
                const saved = await resourceAPI.request<Ascent>(`/api/routes/${encodeURIComponent(local.id)}/ascents/${encodeURIComponent(ascent.id)}`, { method: 'PUT', body: JSON.stringify(ascentPayload(ascent)) });
                savedAscents.set(ascent.id, saved);
              } catch { socialPending = true; }
              if (stale()) return;
            }
            for (const comment of latest.comments || []) {
              if (comment.user_id !== 'local-user' && comment.user_id !== user.id) continue;
              try {
                const saved = await resourceAPI.request<Comment>(`/api/routes/${encodeURIComponent(local.id)}/comments/${encodeURIComponent(comment.id)}`, { method: 'PUT', body: JSON.stringify({ id: comment.id, content: comment.content, is_beta: comment.is_beta }) });
                savedComments.set(comment.id, saved);
              } catch { socialPending = true; }
              if (stale()) return;
            }
            for (const commentId of latest._deletedCommentIds || []) {
              try {
                await resourceAPI.request(`/api/routes/${encodeURIComponent(local.id)}/comments/${encodeURIComponent(commentId)}`, { method: 'DELETE' });
                deletedComments.add(commentId);
              } catch (error) {
                // Already absent is an acknowledged deletion, not a lost retry.
                if (error instanceof ResourceError && error.status === 404) deletedComments.add(commentId);
                else socialPending = true;
              }
              if (stale()) return;
            }
            // Edits made during any await require another acknowledged snapshot.
            if ((routeMutationRevisions.get(local.id) || 0) !== revision) continue;
            set((state) => ({ routes: state.routes.map((route) => {
              if (route.id !== local.id) return route;
              const next: LocalRoute = { ...route, wall_image_url: needsParentSync ? remote.wall_image_url : route.wall_image_url, user_id: user.id,
                ascents: (route.ascents || []).map((ascent) => savedAscents.get(ascent.id) || ascent),
                comments: (route.comments || []).map((comment) => savedComments.get(comment.id) || comment) };
              delete next._createSyncPending;
              const remainingDeletes = (next._deletedCommentIds || []).filter((id) => !deletedComments.has(id));
              if (remainingDeletes.length) next._deletedCommentIds = remainingDeletes;
              else delete next._deletedCommentIds;
              if (socialPending) next._socialSyncPending = true;
              else delete next._socialSyncPending;
              return next;
            }), isOfflineMode: socialPending }));
            break;
          }
        } catch {
          if (stale()) return;
          set({ isOfflineMode: true });
        }
      }
    } finally { resolve(); }
  },

  addRoute: async (route) => {
    const generation = routeAuthGeneration;
    const local = normalizeRouteGrades({
      ...route,
      share_token: route.share_token || nanoid(10),
    }) as LocalRoute;
    local._createSyncPending = true;
    set((state) => ({ routes: [local, ...state.routes] }));
    // Creation uses the same serialized, revision-aware acknowledgement path
    // as offline replay, so edits during its upload cannot be overwritten.
    try {
      await get().syncLocalRoutes();
    } catch {
      if (generation === routeAuthGeneration) set({ isOfflineMode: true });
    }
    // True means saved on this device; the pending flag distinguishes remote success.
    return true;
  },

  updateRoute: async (id, updates) => {
    const previous = get().routes.find((route) => route.id === id) as LocalRoute | undefined;
    if (!previous) return false;
    const generation = routeAuthGeneration;
    routeMutationRevisions.set(id, (routeMutationRevisions.get(id) || 0) + 1);
    const next = normalizeRouteGrades({ ...previous, ...updates, updated_at: new Date().toISOString() });
    set((state) => ({ routes: state.routes.map((route) => route.id === id ? next : route) }));
    if (previous.user_id === 'local-user' || previous._createSyncPending) return true;
    try {
      const payload = routePayload({ ...updates, grade_v: 'grade_v' in updates ? next.grade_v : undefined });
      const remote = await resourceAPI.request<Route>(`/api/routes/${encodeURIComponent(id)}`, { method: 'PATCH', body: JSON.stringify(payload) });
      if (generation !== routeAuthGeneration) return false;
      set((state) => ({ routes: state.routes.map((route) => {
        if (route.id !== id) return route;
        const acknowledged = { ...route } as Route & Record<string, unknown>;
        for (const [key, value] of Object.entries(payload)) {
          if (value !== undefined && Object.is(acknowledged[key], (next as unknown as Record<string, unknown>)[key])) {
            acknowledged[key] = (remote as unknown as Record<string, unknown>)[key];
          }
        }
        if (route.updated_at === next.updated_at) acknowledged.updated_at = remote.updated_at;
        return acknowledged;
      }) }));
      return true;
    } catch {
      if (generation === routeAuthGeneration) set((state) => ({ routes: state.routes.map((route) => {
        if (route.id !== id) return route;
        const restored = { ...route } as Route & Record<string, unknown>;
        for (const key of Object.keys(updates)) {
          if (Object.is(restored[key], (next as unknown as Record<string, unknown>)[key])) {
            restored[key] = (previous as unknown as Record<string, unknown>)[key];
          }
        }
        if (route.updated_at === next.updated_at) restored.updated_at = previous.updated_at;
        return restored;
      }) }));
      return false;
    }
  },

  deleteRoute: async (id) => {
    const previous = get().routes.find((route) => route.id === id) as LocalRoute | undefined;
    if (!previous) return false;
    const generation = routeAuthGeneration;
    routeMutationRevisions.set(id, (routeMutationRevisions.get(id) || 0) + 1);
    set((state) => ({ routes: state.routes.filter((route) => route.id !== id) }));
    if (previous.user_id === 'local-user' || previous._createSyncPending) return true;
    try {
      await resourceAPI.request(`/api/routes/${encodeURIComponent(id)}`, { method: 'DELETE' });
      return generation === routeAuthGeneration;
    } catch {
      if (generation === routeAuthGeneration) set((state) => ({ routes: [previous, ...state.routes] }));
      return false;
    }
  },

  addAscent: async (routeId, ascent) => {
    const previous = get().routes.find((route) => route.id === routeId) as LocalRoute | undefined;
    if (!previous) return false;
    const generation = routeAuthGeneration;
    routeMutationRevisions.set(routeId, (routeMutationRevisions.get(routeId) || 0) + 1);
    const normalized = { ...ascent, grade_v: canonicalizeGrade(ascent.grade_v) };
    set((state) => ({ routes: state.routes.map((route) => route.id === routeId ? { ...route, ascents: [...(route.ascents || []), normalized] } : route) }));
    if (previous.user_id === 'local-user' || previous._createSyncPending) return true;
    try {
      const saved = await resourceAPI.request<Ascent>(`/api/routes/${encodeURIComponent(routeId)}/ascents`, { method: 'POST', body: JSON.stringify(ascentPayload(normalized)) });
      if (generation !== routeAuthGeneration) return false;
      set((state) => ({ routes: state.routes.map((route) => route.id === routeId ? { ...route, ascents: route.ascents?.map((item) => item.id === ascent.id ? saved : item) } : route) }));
      return true;
    } catch {
      if (generation === routeAuthGeneration) set((state) => ({ routes: state.routes.map((route) => route.id === routeId ? { ...route, ascents: route.ascents?.filter((item) => item.id !== ascent.id) } : route) }));
      return false;
    }
  },

  hasUserClimbed: (routeId, userId) => get().routes.find((route) => route.id === routeId)?.ascents?.some((ascent) => ascent.user_id === userId) || false,

  addComment: async (routeId, comment) => {
    const previous = get().routes.find((route) => route.id === routeId) as LocalRoute | undefined;
    if (!previous) return false;
    const generation = routeAuthGeneration;
    routeMutationRevisions.set(routeId, (routeMutationRevisions.get(routeId) || 0) + 1);
    set((state) => ({ routes: state.routes.map((route) => route.id === routeId ? { ...route, comments: [...(route.comments || []), comment] } : route) }));
    if (previous.user_id === 'local-user' || previous._createSyncPending) return true;
    try {
      const saved = await resourceAPI.request<Comment>(`/api/routes/${encodeURIComponent(routeId)}/comments`, { method: 'POST', body: JSON.stringify({ id: comment.id, content: comment.content, is_beta: comment.is_beta }) });
      if (generation !== routeAuthGeneration) return false;
      set((state) => ({ routes: state.routes.map((route) => route.id === routeId ? { ...route, comments: route.comments?.map((item) => item.id === comment.id ? saved : item) } : route) }));
      return true;
    } catch {
      if (generation === routeAuthGeneration) set((state) => ({ routes: state.routes.map((route) => route.id === routeId ? { ...route, comments: route.comments?.filter((item) => item.id !== comment.id) } : route) }));
      return false;
    }
  },

  deleteComment: async (routeId, commentId) => {
    const previous = get().routes.find((route) => route.id === routeId) as LocalRoute | undefined;
    if (!previous) return false;
    const generation = routeAuthGeneration;
    routeMutationRevisions.set(routeId, (routeMutationRevisions.get(routeId) || 0) + 1);
    const pending = previous.user_id === 'local-user' || previous._createSyncPending || previous._socialSyncPending;
    set((state) => ({ routes: state.routes.map((route) => {
      if (route.id !== routeId) return route;
      const next: LocalRoute = { ...route, comments: route.comments?.filter((item) => item.id !== commentId) };
      if (pending) {
        // This route's owner scope is retained by persistence and auth clearing.
        next._deletedCommentIds = [...new Set([...(previous._deletedCommentIds || []), commentId])];
        next._socialSyncPending = true;
      }
      return next;
    }) }));
    if (pending) return true;
    try {
      await resourceAPI.request(`/api/routes/${encodeURIComponent(routeId)}/comments/${encodeURIComponent(commentId)}`, { method: 'DELETE' });
      return generation === routeAuthGeneration;
    } catch {
      if (generation === routeAuthGeneration) set((state) => ({ routes: state.routes.map((route) => route.id === routeId ? previous : route) }));
      return false;
    }
  },

  incrementViewCount: async (routeId) => {
    const generation = routeAuthGeneration;
    const route = get().routes.find((item) => item.id === routeId) as LocalRoute | undefined;
    if (!route || route.user_id === 'local-user' || route._createSyncPending || !route.is_public) return;
    try {
      const { view_count } = await resourceAPI.request<{ view_count: number }>(`/api/routes/${encodeURIComponent(routeId)}/views`, { method: 'POST' });
      if (generation === routeAuthGeneration) set((state) => ({ routes: state.routes.map((item) => item.id === routeId ? { ...item, view_count } : item) }));
    } catch { /* Keep the last confirmed count. */ }
  },

  toggleLike: async (routeId, userId) => {
    const generation = routeAuthGeneration;
    const route = get().routes.find((item) => item.id === routeId) as LocalRoute | undefined;
    if (!route || route.user_id === 'local-user' || route._createSyncPending) return false;
    const current = route.liked_by || [];
    const liked = current.includes(userId);
    const next = liked ? current.filter((id) => id !== userId) : [...current, userId];
    set((state) => ({ routes: state.routes.map((item) => item.id === routeId ? { ...item, liked_by: next, like_count: next.length, is_liked: !liked } : item) }));
    try {
      const saved = await resourceAPI.request<Pick<Route, 'liked_by' | 'like_count' | 'is_liked'>>(`/api/routes/${encodeURIComponent(routeId)}/like`, { method: liked ? 'DELETE' : 'PUT' });
      if (generation !== routeAuthGeneration) return false;
      set((state) => ({ routes: state.routes.map((item) => item.id === routeId ? { ...item, ...saved } : item) }));
      return true;
    } catch {
      if (generation === routeAuthGeneration) set((state) => ({ routes: state.routes.map((item) => item.id === routeId ? { ...item, liked_by: current, like_count: current.length, is_liked: liked } : item) }));
      return false;
    }
  },

  isLikedByUser: (routeId, userId) => {
    const route = get().routes.find((item) => item.id === routeId);
    return route?.is_liked ?? route?.liked_by?.includes(userId) ?? false;
  },
  getLikeCount: (routeId) => {
    const route = get().routes.find((item) => item.id === routeId);
    return route?.liked_by?.length ?? route?.like_count ?? 0;
  },
}), {
  name: 'boarded-routes',
  partialize: (state) => ({ routes: [...quarantinedRoutes, ...state.routes] }),
  merge: (persisted, current) => {
    const routes = (persisted as Partial<RoutesState> | null)?.routes;
    if (!Array.isArray(routes)) return current;
    const normalized = routes.map(normalizeRouteGrades);
    quarantinedRoutes = normalized.filter((route) => route.user_id !== 'local-user');
    return { ...current, routes: normalized.filter((route) => route.user_id === 'local-user') };
  },
}));
