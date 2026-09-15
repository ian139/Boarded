'use client';

import { create } from 'zustand';
import { authClient } from '@/lib/api/auth';
import { resourceAPI, ResourceError, type SessionUser } from '@/lib/api/client';
import { useRoutesStore } from '@/lib/stores/routes-store';
import { useWallsStore } from '@/lib/stores/walls-store';
import type { Profile } from '@boarded/shared/types';
import { boardRedirect } from '@/lib/utils';

interface AuthResult { success: boolean; requiresConfirmation?: boolean; error?: string }
type ProfileUpdateResult = { ok: true } | { ok: false; error: 'conflict' | 'invalid' | 'failed' | 'stale' };
interface UserState {
  user: SessionUser | null;
  profile: Profile | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  isModerator: boolean;
  signup: (email: string, password: string, displayName?: string, callbackURL?: string) => Promise<AuthResult>;
  login: (email: string, password: string) => Promise<AuthResult>;
  logout: () => Promise<void>;
  initializeAuth: () => Promise<void>;
  syncProfile: () => Promise<void>;
  updateProfile: (updates: Partial<Profile>) => Promise<ProfileUpdateResult>;
  uploadAvatar: (file: File) => Promise<string | null>;
}

let authGeneration = 0;
let sessionRequest = 0;
let profileMutationRevision = 0;
let initialized = false;
let routeReconciliation = Promise.resolve();

function reconcileDataForAuthChange(currentUserId?: string): Promise<void> {
  const generation = authGeneration;
  useRoutesStore.getState().clearRemoteRoutes(currentUserId);
  useWallsStore.getState().clearRemoteWalls(currentUserId);
  const run = async () => {
    if (generation !== authGeneration) return;
    try {
      const { user } = await resourceAPI.session();
      if (generation !== authGeneration || user?.id !== currentUserId) return;
      await useRoutesStore.getState().syncLocalRoutes();
      if (generation !== authGeneration) return;
      await Promise.all([useRoutesStore.getState().fetchRoutes(), useWallsStore.getState().fetchWalls()]);
    } catch {
      // Keep local routes available; never sync using an unverified identity.
    }
  };
  routeReconciliation = routeReconciliation.catch(() => undefined).then(run);
  return routeReconciliation;
}


export const useUserStore = create<UserState>()((set, get) => ({
  user: null,
  profile: null,
  isAuthenticated: false,
  isLoading: true,
  isModerator: false,

  initializeAuth: async () => {
    const request = ++sessionRequest;
    try {
      const { user } = await resourceAPI.session();
      if (request !== sessionRequest) return;
      const changed = !initialized || get().user?.id !== user?.id;
      initialized = true;
      if (changed) {
        authGeneration += 1;
        // Remove cached account data before publishing the next identity.
        // Keep an anonymous draft during the first session discovery.
        const privacy = authGeneration > 1 ? resourceAPI.clearPrivateCaches() : Promise.resolve();
        localStorage.removeItem('boarded-user');
        localStorage.removeItem('boarded-auth');
        const reconciliation = reconcileDataForAuthChange(user?.id);
        set({ user, profile: null, isAuthenticated: Boolean(user), isModerator: user?.isModerator ?? false, isLoading: false });
        await Promise.all([privacy, reconciliation]);
      } else {
        set({ user, isAuthenticated: Boolean(user), isModerator: user?.isModerator ?? false, isLoading: false });
      }
      if (request === sessionRequest && user) await get().syncProfile();
    } catch {
      if (request !== sessionRequest) return;
      authGeneration += 1;
      initialized = false;
      // An unknown resource session must not keep the last account visible.
      // The stores quarantine pending account work rather than deleting it.
      useRoutesStore.getState().clearRemoteRoutes();
      useWallsStore.getState().clearRemoteWalls();
      set({ user: null, profile: null, isAuthenticated: false, isModerator: false, isLoading: false });
    }
  },

  signup: async (email, password, displayName, callbackURL) => {
    if (password.length < 8) return { success: false, error: 'Password must be at least 8 characters' };
    try {
      const destination = boardRedirect(
        callbackURL?.startsWith('/login?')
          ? new URLSearchParams(callbackURL.slice('/login?'.length)).get('redirect')
          : null,
        '',
      );
      const loginCallback = destination ? `/login?redirect=${encodeURIComponent(destination)}` : '/login';
      const { error } = await authClient.signUp.email({ email, password, name: displayName?.trim() || email.split('@')[0], callbackURL: loginCallback });
      if (error) return { success: false, error: error.message || 'Unable to create account' };
      await get().initializeAuth();
      return { success: true, requiresConfirmation: !get().isAuthenticated };
    } catch (error) { return { success: false, error: error instanceof Error ? error.message : 'Unable to reach the server. Please try again.' }; }
  },

  login: async (email, password) => {
    try {
      const { error } = await authClient.signIn.email({ email, password });
      if (error) return { success: false, error: error.message || 'Unable to log in' };
      await get().initializeAuth();
      if (!get().isAuthenticated) return { success: false, error: 'Unable to verify your session. Please try again.' };
      return { success: true };
    } catch (error) { return { success: false, error: error instanceof Error ? error.message : 'Unable to reach the server. Please try again.' }; }
  },

  logout: async () => {
    // Revocation must succeed before claiming that this browser is signed out.
    const { error } = await authClient.signOut();
    if (error) throw new Error(error.message || 'Unable to log out. Please try again.');
    sessionRequest += 1;
    authGeneration += 1;
    set({ user: null, profile: null, isAuthenticated: false, isModerator: false, isLoading: false });
    const reconciliation = reconcileDataForAuthChange();
    await resourceAPI.clearPrivateCaches();
    await reconciliation;
  },

  syncProfile: async () => {
    const userId = get().user?.id;
    const generation = authGeneration;
    const mutationRevision = profileMutationRevision;
    if (!userId) return;
    try {
      const profile = await resourceAPI.request<Profile>('/api/profile');
      // A refresh started before a saved edit must not put the old profile back.
      if (generation === authGeneration && get().user?.id === userId && mutationRevision === profileMutationRevision) set({ profile });
    } catch { /* Keep the last profile for this verified account. */ }
  },

  updateProfile: async (updates) => {
    const userId = get().user?.id;
    const generation = authGeneration;
    if (!userId) return { ok: false, error: 'stale' };
    try {
      const { username, full_name, avatar_url, bio, home_area } = updates;
      const profile = await resourceAPI.request<Profile>('/api/profile', {
        method: 'PATCH',
        body: JSON.stringify({ username, full_name, avatar_url, bio, home_area }),
      });
      if (generation !== authGeneration || get().user?.id !== userId) return { ok: false, error: 'stale' };
      profileMutationRevision += 1;
      set({ profile });
      return { ok: true };
    } catch (error) {
      if (generation !== authGeneration || get().user?.id !== userId) return { ok: false, error: 'stale' };
      if (error instanceof ResourceError) {
        if (error.status === 409) return { ok: false, error: 'conflict' };
        if (error.status === 422) return { ok: false, error: 'invalid' };
      }
      return { ok: false, error: 'failed' };
    }
  },

  uploadAvatar: async (file) => {
    const userId = get().user?.id;
    const generation = authGeneration;
    if (!userId) return null;
    try {
      const form = new FormData();
      form.set('file', file);
      const result = await resourceAPI.request<{ profile: Profile; avatar_url: string }>('/api/profile/avatar', { method: 'POST', body: form });
      if (generation !== authGeneration || get().user?.id !== userId) return null;
      profileMutationRevision += 1;
      set({ profile: result.profile });
      return result.avatar_url;
    } catch { return null; }
  },
}));
