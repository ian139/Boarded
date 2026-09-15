import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { setImmediate } from 'node:timers/promises';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';
import { create } from 'zustand';
import type { SessionUser } from '../api/client';
import type * as ResourceClient from '../api/client';
import type { useUserStore } from './user-store';
import type { AuthProvider as AuthProviderComponent } from '../../components/providers/AuthProvider';

type UserStore = typeof useUserStore;
type AuthProvider = typeof AuthProviderComponent;

const require = createRequire(import.meta.url);

// Load the actual client modules with isolated module state and controlled network boundaries.
function loadModule<T>(path: string, mocks: Record<string, unknown> = {}): T {
  const filename = new URL(path, import.meta.url);
  const source = ts.transpileModule(readFileSync(filename, 'utf8'), {
    fileName: filename.pathname,
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX },
  }).outputText;
  const module = { exports: {} };
  runInNewContext(source, {
    module,
    exports: module.exports,
    require: (name: string) => Object.hasOwn(mocks, name) ? mocks[name] : require(name),
    URLSearchParams,
    FormData,
    localStorage: { removeItem() {} },
  }, { filename: filename.pathname });
  return module.exports as T;
}

const { ResourceError } = loadModule<typeof ResourceClient>('../api/client.ts');

function user(id: string): SessionUser {
  return { id, email: `${id}@example.com`, displayName: id, createdAt: '2026-01-01T00:00:00Z', isModerator: false };
}

function authHarness() {
  let resourceUser: SessionUser | null = null;
  let sessionFailure = false;
  let logoutError: { message: string } | null = null;
  let signupCallback: string | undefined;
  let sessionRequests = 0;
  let snapshot = { isPending: true, isRefetching: false, data: null as { user: SessionUser } | null };
  let dependencies: readonly unknown[] | undefined;
  let effect: (() => void) | undefined;
  let updateProfileRequest: () => Promise<unknown> = async () => { throw new Error('Unexpected profile update'); };
  let profileRequest: () => Promise<unknown> = async () => ({ id: resourceUser?.id, username: resourceUser?.displayName });
  const authClient = {
    useSession: () => snapshot,
    signUp: { email: async (input: { callbackURL: string }) => { signupCallback = input.callbackURL; return { error: null }; } },
    signOut: async () => ({ error: logoutError }),
  };
  const cacheStore = { getState: () => ({
    clearRemoteRoutes() {},
    clearRemoteWalls() {},
    syncLocalRoutes: async () => {},
    fetchRoutes: async () => {},
    fetchWalls: async () => {},
  }) };
  const { useUserStore: store } = loadModule<{ useUserStore: UserStore }>('./user-store.ts', {
    zustand: { create },
    '@/lib/api/auth': { authClient },
    '@/lib/api/client': { ResourceError, resourceAPI: {
      session: async () => {
        sessionRequests += 1;
        if (sessionFailure) { sessionFailure = false; throw new Error('Temporary resource failure'); }
        return { user: resourceUser };
      },
      clearPrivateCaches: async () => {},
      request: async (_path: string, options?: RequestInit) => options?.method === 'PATCH' || options?.method === 'POST'
        ? updateProfileRequest()
        : profileRequest(),
    } },
    '@/lib/stores/routes-store': { useRoutesStore: cacheStore },
    '@/lib/stores/walls-store': { useWallsStore: cacheStore },
    '@/lib/utils': loadModule('../utils.ts'),
  });
  const { AuthProvider: Provider } = loadModule<{ AuthProvider: AuthProvider }>('../../components/providers/AuthProvider.tsx', {
    react: { useEffect: (nextEffect: () => void, nextDependencies: readonly unknown[]) => {
      if (!dependencies || nextDependencies.some((value, index) => !Object.is(value, dependencies?.[index]))) effect = nextEffect;
      dependencies = nextDependencies;
    } },
    '@/lib/stores/user-store': { useUserStore: (selector: (state: unknown) => unknown) => selector(store.getState()) },
    '@/lib/api/auth': { authClient },
  });
  return {
    store,
    setResourceUser: (next: SessionUser | null) => { resourceUser = next; },
    setUpdateProfileRequest: (request: () => Promise<unknown>) => { updateProfileRequest = request; },
    setProfileRequest: (request: () => Promise<unknown>) => { profileRequest = request; },
    failSession: () => { sessionFailure = true; },
    failLogout: () => { logoutError = { message: 'Revocation failed' }; },
    getSignupCallback: () => signupCallback,
    getSessionRequests: () => sessionRequests,
    render: async (next: typeof snapshot) => {
      snapshot = next;
      Provider({ children: null });
      const scheduled = effect;
      effect = undefined;
      scheduled?.();
      await setImmediate();
    },
  };
}

test('initial verification preserves the same safe login destination as resend', async () => {
  const auth = authHarness();
  const loginHref = `/login?redirect=${encodeURIComponent('/editor?edit=route-123#holds')}`;
  const result = await auth.store.getState().signup('new@example.com', 'safe-password', 'New', loginHref);
  assert.equal(result.requiresConfirmation, true);
  assert.equal(auth.getSignupCallback(), loginHref);
  await auth.store.getState().signup('new@example.com', 'safe-password', 'New', '/login?redirect=https%3A%2F%2Fevil.example');
  assert.equal(auth.getSignupCallback(), '/login');
});

test('a completed same-user session refresh recovers after transient resource discovery failure', async () => {
  const auth = authHarness();
  const alice = user('alice');
  const completed = { isPending: false, isRefetching: false, data: { user: alice } };
  auth.setResourceUser(alice);
  auth.failSession();
  await auth.render(completed);
  assert.equal(auth.store.getState().user, null);
  assert.equal(auth.store.getState().isAuthenticated, false);

  await auth.render({ ...completed, isRefetching: true });
  assert.equal(auth.store.getState().user, null);
  await auth.render(completed);
  assert.equal(auth.store.getState().user?.id, 'alice');
  assert.equal(auth.store.getState().isAuthenticated, true);
  const requests = auth.getSessionRequests();
  await auth.render(completed);
  assert.equal(auth.getSessionRequests(), requests, 'unchanged settled renders must not start a reconciliation loop');
});

test('failed resource discovery during account switching removes the previous identity and profile', async () => {
  const auth = authHarness();
  const alice = user('alice');
  const bob = user('bob');
  auth.setResourceUser(alice);
  await auth.render({ isPending: false, isRefetching: false, data: { user: alice } });
  assert.equal(auth.store.getState().profile?.id, 'alice');

  auth.setResourceUser(bob);
  auth.failSession();
  await auth.render({ isPending: false, isRefetching: false, data: { user: bob } });
  assert.equal(auth.store.getState().user, null);
  assert.equal(auth.store.getState().profile, null);
  assert.equal(auth.store.getState().isAuthenticated, false);
  await auth.render({ isPending: false, isRefetching: true, data: { user: bob } });
  await auth.render({ isPending: false, isRefetching: false, data: { user: bob } });
  assert.equal(auth.store.getState().user?.id, 'bob');
  assert.equal(auth.store.getState().profile?.id, 'bob');
});

test('failed revocation does not claim that logout succeeded', async () => {
  const auth = authHarness();
  auth.setResourceUser(user('alice'));
  await auth.store.getState().initializeAuth();
  auth.failLogout();
  await assert.rejects(auth.store.getState().logout(), /Revocation failed/);
  assert.equal(auth.store.getState().isAuthenticated, true);
  assert.equal(auth.store.getState().user?.id, 'alice');
});

test('profile save publishes only the persisted response and leaves the display name alone', async () => {
  const auth = authHarness();
  auth.setResourceUser(user('alice'));
  await auth.store.getState().initializeAuth();
  const { promise, resolve: complete } = Promise.withResolvers<unknown>();
  auth.setUpdateProfileRequest(() => promise);
  const save = auth.store.getState().updateProfile({ username: 'new-handle' });
  assert.equal(auth.store.getState().profile?.username, 'alice');
  complete({ id: 'alice', username: 'new-handle', avatar_url: '/api/files/current-avatar' });
  const result = await save;
  assert.equal(result.ok, true);
  assert.equal(auth.store.getState().profile?.username, 'new-handle');
  assert.equal(auth.store.getState().profile?.avatar_url, '/api/files/current-avatar');
  assert.equal(auth.store.getState().user?.displayName, 'alice');
});

test('profile update distinguishes recoverable failures without replacing the saved profile', async (t) => {
  for (const [failure, expected] of [
    [new ResourceError(409, 'conflict', 'Taken'), 'conflict'],
    [new ResourceError(422, 'invalid_payload', 'Invalid'), 'invalid'],
    [new ResourceError(503, 'unavailable', 'Unavailable'), 'failed'],
    [new Error('Network unavailable'), 'failed'],
  ] as const) {
    await t.test(failure.message, async () => {
      const auth = authHarness();
      auth.setResourceUser(user('alice'));
      await auth.store.getState().initializeAuth();
      const saved = auth.store.getState().profile;
      auth.setUpdateProfileRequest(async () => { throw failure; });
      const result = await auth.store.getState().updateProfile({ username: 'unsaved' });
      assert.equal(result.ok, false);
      if (!result.ok) assert.equal(result.error, expected);
      assert.equal(auth.store.getState().profile, saved);
    });
  }
});

test('late profile save outcomes stay stale after switching away and back to the same account', async (t) => {
  for (const outcome of ['success', 'conflict'] as const) {
    await t.test(outcome, async () => {
      const auth = authHarness();
      auth.setResourceUser(user('alice'));
      await auth.store.getState().initializeAuth();
      const { promise, resolve: complete, reject: fail } = Promise.withResolvers<unknown>();
      auth.setUpdateProfileRequest(() => promise);
      const save = auth.store.getState().updateProfile({ username: 'old-session-name' });
      auth.setResourceUser(user('bob'));
      await auth.store.getState().initializeAuth();
      assert.equal(auth.store.getState().profile?.id, 'bob');
      auth.setResourceUser(user('alice'));
      await auth.store.getState().initializeAuth();
      const currentProfile = auth.store.getState().profile;
      if (outcome === 'success') complete({ id: 'alice', username: 'old-session-name' });
      else fail(new ResourceError(409, 'conflict', 'Taken'));
      const result = await save;
      assert.equal(result.ok, false);
      if (!result.ok) assert.equal(result.error, 'stale');
      assert.equal(auth.store.getState().profile, currentProfile);
      assert.equal(auth.store.getState().profile?.username, 'alice');
    });
  }
});

test('a delayed profile refresh cannot revert a saved username or avatar', async (t) => {
  for (const mutation of ['username', 'avatar'] as const) {
    await t.test(mutation, async () => {
      const auth = authHarness();
      auth.setResourceUser(user('alice'));
      await auth.store.getState().initializeAuth();
      const oldProfile = auth.store.getState().profile;
      const { promise, resolve } = Promise.withResolvers<unknown>();
      auth.setProfileRequest(() => promise);
      const refresh = auth.store.getState().syncProfile();
      const saved = {
        ...oldProfile,
        username: mutation === 'username' ? 'saved-name' : 'alice',
        avatar_url: mutation === 'avatar' ? '/api/files/saved-avatar' : null,
      };
      auth.setUpdateProfileRequest(async () => mutation === 'username'
        ? saved
        : { profile: saved, avatar_url: saved.avatar_url });
      if (mutation === 'username') {
        assert.equal((await auth.store.getState().updateProfile({ username: 'saved-name' })).ok, true);
      } else {
        assert.equal(await auth.store.getState().uploadAvatar(new File(['photo'], 'photo.png', { type: 'image/png' })), saved.avatar_url);
      }
      resolve(oldProfile);
      await refresh;
      assert.equal(auth.store.getState().profile?.username, saved.username);
      assert.equal(auth.store.getState().profile?.avatar_url, saved.avatar_url);

      auth.setProfileRequest(async () => ({ ...saved, username: 'newer-server-name' }));
      await auth.store.getState().syncProfile();
      assert.equal(auth.store.getState().profile?.username, 'newer-server-name', 'a subsequent fresh read must still publish');
    });
  }
});
