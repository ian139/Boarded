import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';
import ts from 'typescript';
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import * as grades from '../../packages/shared/utils/grades.ts';
import type { Route, Comment, Ascent } from '@boarded/shared/types';
import type { useRoutesStore as RoutesStore } from './routes-store';

type PendingRoute = Route & { _createSyncPending?: boolean; _socialSyncPending?: boolean; _deletedCommentIds?: string[] };
type RequestHandler = (path: string, options?: RequestInit) => Promise<unknown>;

const route = (overrides: Partial<PendingRoute> = {}): PendingRoute => ({
  id: 'route-1', user_id: 'owner-a', wall_id: 'default-wall', name: 'Original',
  holds: [], is_public: false, view_count: 0, share_token: 'share-1',
  created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z',
  ascents: [], comments: [], liked_by: [], like_count: 0, is_liked: false,
  ...overrides,
});
const comment: Comment = { id: 'comment-1', route_id: 'route-1', user_id: 'owner-a', content: 'New comment', is_beta: false, created_at: '2026-01-02T00:00:00Z' };
const ascent: Ascent = { id: 'ascent-1', route_id: 'route-1', user_id: 'owner-a', grade_v: 'V3', created_at: '2026-01-02T00:00:00Z' };

// Execute the production store with real Zustand persistence and a deterministic
// HTTP boundary. The VM resolves browser aliases without a separate test loader.
function loadStore(seed: PendingRoute[], request: RequestHandler) {
  const values = new Map([['boarded-routes', JSON.stringify({ state: { routes: seed }, version: 0 })]]);
  const storage = {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => { values.set(key, value); },
    removeItem: (key: string) => { values.delete(key); },
  };
  class ResourceError extends Error {
    status: number;
    constructor(status: number) { super('Request failed'); this.status = status; }
  }
  const resourceAPI = {
    session: async () => ({ user: { id: 'owner-a' } }),
    request,
    upload: async () => { throw new Error('Unexpected image upload'); },
  };
  const compiled = ts.transpileModule(readFileSync(new URL('./routes-store.ts', import.meta.url), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const module = { exports: {} as { useRoutesStore: typeof RoutesStore } };
  vm.runInNewContext(compiled, {
    module, exports: module.exports, console, Promise,
    require: (name: string) => {
      if (name === 'zustand') return { create };
      if (name === 'zustand/middleware') return {
        persist: (initializer: Parameters<typeof persist>[0], options: Parameters<typeof persist>[1]) =>
          persist(initializer, { ...options, storage: createJSONStorage(() => storage) }),
      };
      if (name === '@/lib/api/client') return { resourceAPI, ResourceError };
      if (name === '@boarded/shared/utils/grades') return grades;
      if (name === 'nanoid') return { nanoid: () => 'generated-share' };
      throw new Error(`Unexpected import ${name}`);
    },
  });
  return {
    store: module.exports.useRoutesStore,
    persisted: () => JSON.parse(values.get('boarded-routes')!).state.routes as PendingRoute[],
  };
}

test('hydration and failed discovery hide account data without discarding owned pending work', async () => {
  const guest = route({ id: 'guest', user_id: 'local-user' });
  const pending = route({ _createSyncPending: true, name: 'Unsynced private holds' });
  const cachedPrivate = route({ id: 'cached-private' });
  const { store, persisted } = loadStore([guest, pending, cachedPrivate], async () => { throw new Error('Offline'); });
  assert.deepEqual(Array.from(store.getState().routes, (item) => item.id), ['guest']);
  store.getState().clearRemoteRoutes();
  assert.deepEqual(Array.from(store.getState().routes, (item) => item.id), ['guest']);
  assert.equal(persisted().find((item) => item.id === pending.id)?.name, pending.name);
  store.getState().clearRemoteRoutes('owner-b');
  assert.equal(store.getState().routes.some((item) => item.id === pending.id), false);
  store.getState().clearRemoteRoutes('owner-a');
  assert.equal(store.getState().routes.find((item) => item.id === pending.id)?.name, pending.name);
});

test('social-only replay preserves another device’s parent edit and foreign child authors', async () => {
  const foreign = { ...comment, id: 'foreign-comment', user_id: 'owner-b' };
  const cached = route({ name: 'Stale name', _socialSyncPending: true, comments: [comment, foreign] });
  const server = route({ name: 'Changed on another device', is_public: true, comments: [foreign] });
  const { store } = loadStore([cached], async (path, options) => {
    if (!options?.method && path === '/api/routes/route-1') return server;
    if (options?.method === 'PUT' && path.endsWith('/comments/comment-1')) return comment;
    throw new Error(`Unexpected mutation ${options?.method} ${path}`);
  });
  store.getState().clearRemoteRoutes('owner-a');
  await store.getState().syncLocalRoutes();
  const saved = store.getState().routes[0] as PendingRoute;
  assert.equal(saved.name, server.name);
  assert.equal(saved.is_public, true);
  assert.equal(saved.comments?.find((item) => item.id === foreign.id)?.user_id, 'owner-b');
  assert.equal(saved._socialSyncPending, undefined);
});

test('delayed parent PATCH acknowledgement keeps newly completed comments, ascents and likes', async () => {
  const patch = Promise.withResolvers<Route>();
  const entered = Promise.withResolvers<void>();
  const initial = route();
  const { store, persisted } = loadStore([], async (path, options) => {
    if (options?.method === 'PATCH') { entered.resolve(); return patch.promise; }
    if (path.endsWith('/comments')) return comment;
    if (path.endsWith('/ascents')) return ascent;
    if (path.endsWith('/like')) return { liked_by: ['owner-a'], like_count: 1, is_liked: true };
    throw new Error(`Unexpected request ${path}`);
  });
  store.getState().clearRemoteRoutes('owner-a');
  store.setState({ routes: [initial] });
  const updating = store.getState().updateRoute(initial.id, { is_public: true });
  await entered.promise;
  await store.getState().addComment(initial.id, comment);
  await store.getState().addAscent(initial.id, ascent);
  await store.getState().toggleLike(initial.id, 'owner-a');
  patch.resolve({ ...initial, is_public: true });
  assert.equal(await updating, true);
  const saved = persisted()[0];
  assert.equal(saved.comments?.[0]?.content, comment.content);
  assert.equal(saved.ascents?.[0]?.grade_v, ascent.grade_v);
  assert.deepEqual(saved.liked_by, ['owner-a']);
  assert.equal(saved.is_public, true);
});

test('edits made during create survive failed PATCH, refetch, and owner-verified retry', async () => {
  const creation = Promise.withResolvers<Route>();
  const entered = Promise.withResolvers<void>();
  let firstCreate = true;
  let failPatch = true;
  let server = route();
  const { store } = loadStore([route({ user_id: 'local-user', _createSyncPending: true })], async (path, options) => {
    if (options?.method === 'POST') {
      if (firstCreate) { firstCreate = false; entered.resolve(); return creation.promise; }
      return server;
    }
    if (options?.method === 'PATCH') {
      const updates = JSON.parse(String(options.body));
      assert.equal(updates.name, 'Edited while uploading');
      if (failPatch) { failPatch = false; throw new Error('Connection lost'); }
      server = { ...server, ...updates };
      return server;
    }
    if (path === '/api/routes') return [server];
    throw new Error(`Unexpected request ${path}`);
  });
  store.getState().clearRemoteRoutes('owner-a');
  const syncing = store.getState().syncLocalRoutes();
  await entered.promise;
  await store.getState().updateRoute(server.id, { name: 'Edited while uploading' });
  creation.resolve(server);
  await syncing;
  await store.getState().fetchRoutes();
  assert.equal(store.getState().routes[0].name, 'Edited while uploading');
  assert.equal((store.getState().routes[0] as PendingRoute)._createSyncPending, true);
  await store.getState().syncLocalRoutes();
  assert.equal(server.name, 'Edited while uploading');
  assert.equal((store.getState().routes[0] as PendingRoute)._createSyncPending, undefined);
});

test('failed pending comment deletion survives reload until server acknowledgement', async () => {
  let remoteCommentExists = true;
  let failDeletion = true;
  const server = route({ comments: [comment] });
  const request: RequestHandler = async (_path, options) => {
    if (options?.method === 'DELETE') {
      if (failDeletion) { failDeletion = false; throw new Error('Disk unavailable'); }
      remoteCommentExists = false;
      return { id: comment.id };
    }
    return server;
  };
  const first = loadStore([route({ comments: [comment], _createSyncPending: true })], request);
  first.store.getState().clearRemoteRoutes('owner-a');
  await first.store.getState().deleteComment(server.id, comment.id);
  await first.store.getState().syncLocalRoutes();
  assert.equal(remoteCommentExists, true);
  assert.deepEqual(first.persisted()[0]._deletedCommentIds, [comment.id]);
  const restored = loadStore(first.persisted(), request);
  restored.store.getState().clearRemoteRoutes('owner-a');
  await restored.store.getState().syncLocalRoutes();
  assert.equal(remoteCommentExists, false);
  assert.equal(restored.persisted()[0]._deletedCommentIds, undefined);
  assert.equal(restored.persisted()[0]._socialSyncPending, undefined);
});
