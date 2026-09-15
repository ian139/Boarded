'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useBoardTheme, type BoardTheme } from '@/components/original-board/theme';
import { useRoutesStore } from '@/lib/stores/routes-store';
import { useWallsStore } from '@/lib/stores/walls-store';
import { useUserStore } from '@/lib/stores/user-store';
import { toast } from 'sonner';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogDescription,
} from '@/components/original-board/ui/dialog';
import { Button } from '@/components/original-board/ui/button';
import { Input } from '@/components/original-board/ui/input';
import { Label } from '@/components/ui/label';
import { cn } from '@/lib/utils';
import { resourceAPI, ResourceError } from '@/lib/api/client';

interface StorageUsage {
  totalBytes: number;
  breakdown: Array<{ wallId: string; bytes: number; latestTs: string | null }>;
}

interface CleanupFile {
  id: string;
  label: string;
  bytes: number;
  updated_at: string;
}

export default function BoardSettingsPage() {
  const router = useRouter();
  const { theme, setTheme } = useBoardTheme();
  const routes = useRoutesStore((state) => state.routes);
  const walls = useWallsStore((state) => state.walls);
  const { user, isAuthenticated, logout, isModerator, login } = useUserStore();
  const currentUserDisplayName = user?.displayName || 'Guest';
  const canManageStorage = isAuthenticated && !!user && isModerator;
  const requestGeneration = useRef(0);
  const [storageRevision, setStorageRevision] = useState(0);
  const [storageBytes, setStorageBytes] = useState<number | null>(null);
  const [storageLoading, setStorageLoading] = useState(false);
  const [storageError, setStorageError] = useState<string | null>(null);
  const [storageByWall, setStorageByWall] = useState<
    Array<{ wallId: string; bytes: number; latestTs: string | null }>
  >([]);
  const [storageHistory, setStorageHistory] = useState<Array<{ ts: string; bytes: number }>>([]);
  const [showCleanup, setShowCleanup] = useState(false);
  const [isCleaning, setIsCleaning] = useState(false);
  const [cleanupPreview, setCleanupPreview] = useState<CleanupFile[]>([]);
  const [cleanupError, setCleanupError] = useState<string | null>(null);
  const [isPreviewLoading, setIsPreviewLoading] = useState(false);
  const [showClearData, setShowClearData] = useState(false);
  const [isClearingData, setIsClearingData] = useState(false);
  const [showModLogin, setShowModLogin] = useState(false);
  const [modEmail, setModEmail] = useState('');
  const [modPassword, setModPassword] = useState('');
  const [modLoading, setModLoading] = useState(false);
  const [modError, setModError] = useState('');

  const isCurrentModeratorRequest = useCallback((generation: number) => {
    const current = useUserStore.getState();
    return generation === requestGeneration.current &&
      current.isAuthenticated && !!current.user && current.isModerator;
  }, []);

  const handleLogout = async () => {
    try {
      await logout();
      toast.success('Logged out');
      router.push('/');
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Unable to log out');
    }
  };

  const handleModLogin = async () => {
    setModLoading(true);
    setModError('');
    try {
      const result = await login(modEmail, modPassword);
      if (!result.success) {
        setModError(result.error || 'Login failed');
        return;
      }
      const current = useUserStore.getState();
      setModPassword('');
      if (!current.isAuthenticated || !current.user || !current.isModerator) {
        setModError('Signed in, but this account does not have moderator access.');
        return;
      }
      toast.success('Logged in as moderator');
      setShowModLogin(false);
      setModEmail('');
    } catch (error) {
      setModError(error instanceof Error ? error.message : 'Login failed');
    } finally {
      setModLoading(false);
    }
  };

  const handleClearData = async () => {
    setIsClearingData(true);
    requestGeneration.current += 1;
    setStorageBytes(null);
    setStorageByWall([]);
    setStorageHistory([]);
    setStorageLoading(false);
    setStorageError(null);
    setCleanupPreview([]);
    setCleanupError(null);
    setShowCleanup(false);
    setIsCleaning(false);
    setIsPreviewLoading(false);
    try {
      await resourceAPI.clearPrivateCaches();
      const draftKeys = Object.keys(localStorage).filter((key) => key.startsWith('boarded-draft:'));
      for (const key of [
        'boarded-routes',
        'boarded-walls',
        'boarded-draft',
        'boarded-user',
        'boarded-storage-history',
        ...draftKeys,
      ]) {
        localStorage.removeItem(key);
      }
      window.location.reload();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Unable to clear local data');
      setIsClearingData(false);
    }
  };

  useEffect(() => {
    const loadStorageUsage = async (generation: number) => {
      try {
        const { totalBytes, breakdown } = await resourceAPI.request<StorageUsage>('/api/admin/storage');
        if (!isCurrentModeratorRequest(generation)) return;
        setStorageByWall([...breakdown].sort((a, b) => b.bytes - a.bytes));
        setStorageBytes(totalBytes);

        const historyKey = 'boarded-storage-history';
        let history: Array<{ ts: string; bytes: number }> = [];
        try {
          const saved: unknown = JSON.parse(localStorage.getItem(historyKey) || '[]');
          if (Array.isArray(saved)) {
            history = saved.filter((entry): entry is { ts: string; bytes: number } =>
              !!entry && typeof entry.ts === 'string' &&
              Number.isFinite(Date.parse(entry.ts)) &&
              typeof entry.bytes === 'number' && Number.isFinite(entry.bytes)
            );
          }
        } catch {
          // A missing or invalid local history must not hide server usage.
        }
        const now = new Date();
        const last = history[history.length - 1];
        const nextHistory = !last || now.getTime() - Date.parse(last.ts) > 12 * 60 * 60 * 1000
          ? [...history, { ts: now.toISOString(), bytes: totalBytes }].slice(-30)
          : history;
        setStorageHistory(nextHistory);
        try {
          localStorage.setItem(historyKey, JSON.stringify(nextHistory));
        } catch {
          // Storage usage remains available when local persistence is disabled.
        }
      } catch (error) {
        if (isCurrentModeratorRequest(generation)) {
          setStorageError(error instanceof Error ? error.message : 'Unable to load storage usage');
        }
      } finally {
        if (isCurrentModeratorRequest(generation)) setStorageLoading(false);
      }
    };

    const resetStorageScope = () => {
      const generation = ++requestGeneration.current;
      setStorageBytes(null);
      setStorageByWall([]);
      setStorageHistory([]);
      setStorageError(null);
      setStorageLoading(false);
      setCleanupPreview([]);
      setCleanupError(null);
      setShowCleanup(false);
      setIsCleaning(false);
      setIsPreviewLoading(false);
      if (isCurrentModeratorRequest(generation)) {
        setStorageLoading(true);
        void loadStorageUsage(generation);
      }
    };

    const unsubscribe = useUserStore.subscribe((current, previous) => {
      if (
        current.user?.id !== previous.user?.id ||
        current.isAuthenticated !== previous.isAuthenticated ||
        current.isModerator !== previous.isModerator
      ) {
        resetStorageScope();
      }
    });
    resetStorageScope();
    return () => {
      unsubscribe();
      requestGeneration.current += 1;
    };
  }, [isCurrentModeratorRequest, storageRevision]);

  const formatBytes = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    const kb = bytes / 1024;
    if (kb < 1024) return `${kb.toFixed(1)} KB`;
    const mb = kb / 1024;
    if (mb < 1024) return `${mb.toFixed(1)} MB`;
    const gb = mb / 1024;
    return `${gb.toFixed(2)} GB`;
  };

  const loadCleanupPreview = async () => {
    const generation = requestGeneration.current;
    if (!isCurrentModeratorRequest(generation)) return;
    setCleanupPreview([]);
    setCleanupError(null);
    setIsPreviewLoading(true);
    try {
      const { files } = await resourceAPI.request<{ files: CleanupFile[] }>(
        '/api/admin/storage/cleanup-preview',
        { method: 'POST' }
      );
      if (isCurrentModeratorRequest(generation)) setCleanupPreview(files);
    } catch (error) {
      if (isCurrentModeratorRequest(generation)) {
        setCleanupError(error instanceof Error ? error.message : 'Failed to load cleanup preview');
      }
    } finally {
      if (isCurrentModeratorRequest(generation)) setIsPreviewLoading(false);
    }
  };

  const runStorageCleanup = async () => {
    const generation = requestGeneration.current;
    if (!isCurrentModeratorRequest(generation) || isCleaning || isPreviewLoading || !cleanupPreview.length) return;
    setIsCleaning(true);
    setCleanupError(null);
    const deletedFileIds = new Set<string>();
    try {
      for (let offset = 0; offset < cleanupPreview.length; offset += 1000) {
        if (!isCurrentModeratorRequest(generation)) return;
        const { deletedIds } = await resourceAPI.request<{ deletedIds: string[] }>(
          '/api/admin/storage/cleanup',
          {
            method: 'POST',
            body: JSON.stringify({
              fileIds: cleanupPreview.slice(offset, offset + 1000).map((file) => file.id),
            }),
          }
        );
        if (!isCurrentModeratorRequest(generation)) return;
        for (const id of deletedIds) deletedFileIds.add(id);
      }
      toast.success(
        deletedFileIds.size > 0
          ? `Deleted ${deletedFileIds.size} unused images`
          : 'No previewed images are eligible for deletion'
      );
      setCleanupPreview([]);
      setShowCleanup(false);
      setStorageRevision((revision) => revision + 1);
    } catch (error) {
      if (isCurrentModeratorRequest(generation)) {
        if (error instanceof ResourceError && error.payload && typeof error.payload === 'object' &&
          'deletedIds' in error.payload && Array.isArray(error.payload.deletedIds)) {
          for (const id of error.payload.deletedIds) {
            if (typeof id === 'string') deletedFileIds.add(id);
          }
        }
        const message = error instanceof Error ? error.message : 'Unable to complete cleanup';
        setCleanupPreview(cleanupPreview.filter((file) => !deletedFileIds.has(file.id)));
        setCleanupError(
          `Cleanup incomplete. ${deletedFileIds.size} images confirmed deleted. ${message}. Retry the remaining previewed images.`
        );
      }
    } finally {
      if (isCurrentModeratorRequest(generation)) setIsCleaning(false);
    }
  };

  const handleExportData = () => {
    const data = {
      routes,
      walls,
      exportedAt: new Date().toISOString(),
    };

    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `boarded-backup-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
    toast.success('Data exported!');
  };

  return (
    <div className="app-shell min-h-dvh pb-28">
      {/* Header */}
      <header className="page-header px-6 pt-5 pb-5">
        <div className="flex items-center gap-3">
          <Link
            href="/profile"
            aria-label="Back to profile"
            className="size-10 rounded-xl bg-muted/50 flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
          >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
            </svg>
          </Link>
          <h1 className="text-xl font-bold">Settings</h1>
        </div>
      </header>

      <main className="page-frame max-w-3xl px-6 py-8 space-y-10">
        {/* Account */}
        <section>
          <h2 className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-4">
            Account
          </h2>

          {isAuthenticated && user ? (
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <div className="size-12 rounded-full bg-primary/10 flex items-center justify-center">
                  <span className="text-lg font-semibold text-primary">
                    {currentUserDisplayName.charAt(0).toUpperCase()}
                  </span>
                </div>
                <div>
                  <p className="font-medium">{currentUserDisplayName}</p>
                  <p className="text-sm text-muted-foreground">{user.email}</p>
                </div>
              </div>
              <button
                onClick={handleLogout}
                className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors"
              >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M12 9l-3 3m0 0l3 3m-3-3h12.75" />
                </svg>
                Log out
              </button>
            </div>
          ) : (
            <div className="flex gap-3">
              <Link
                href="/login?redirect=/settings"
                className="flex-1 py-2.5 px-4 rounded-xl bg-muted/50 text-center text-sm font-medium hover:bg-muted transition-colors"
              >
                Log In
              </Link>
              <Link
                href="/signup?redirect=/settings"
                className="flex-1 py-2.5 px-4 rounded-xl bg-primary text-primary-foreground text-center text-sm font-medium hover:opacity-90 transition-opacity"
              >
                Sign Up
              </Link>
            </div>
          )}
        </section>

        {/* Appearance */}
        <section>
          <h2 className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-4">
            Appearance
          </h2>
          <div className="flex gap-2">
            {[
              {
                value: 'light' as BoardTheme,
                label: 'Light',
                icon: (
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" />
                  </svg>
                ),
              },
              {
                value: 'dark' as BoardTheme,
                label: 'Dark',
                icon: (
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z" />
                  </svg>
                ),
              },
              {
                value: 'system' as BoardTheme,
                label: 'Auto',
                icon: (
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25m18 0A2.25 2.25 0 0018.75 3H5.25A2.25 2.25 0 003 5.25m18 0V12a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 12V5.25" />
                  </svg>
                ),
              },
            ].map((option) => (
              <button
                key={option.value}
                onClick={() => setTheme(option.value)}
                className={cn(
                  'flex-1 flex flex-col items-center gap-2 py-3 px-4 rounded-xl transition-all',
                  theme === option.value
                    ? 'bg-primary/10 text-primary'
                    : 'bg-muted/30 text-muted-foreground hover:bg-muted/50 hover:text-foreground'
                )}
              >
                {option.icon}
                <span className="text-xs font-medium">{option.label}</span>
              </button>
            ))}
          </div>
        </section>

        {/* Data */}
        <section>
          <h2 className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-4">
            Data
          </h2>
          <div className="space-y-3">
            <p className="text-sm text-muted-foreground">
              <span className="font-medium text-foreground">{routes.length}</span> routes saved
            </p>
            <p className="text-sm text-muted-foreground">
              <span className="font-medium text-foreground">{walls.length}</span> walls saved
            </p>
            <div className="text-sm text-muted-foreground">
              <span className="font-medium text-foreground">Storage usage:</span>{' '}
              {!canManageStorage
                ? 'Moderator access required'
                : storageLoading
                ? 'Loading...'
                : storageError
                  ? 'Unavailable'
                  : storageBytes !== null
                    ? formatBytes(storageBytes)
                    : '—'}
            </div>
            {canManageStorage && storageError && (
              <p className="text-sm text-destructive">{storageError}</p>
            )}
            {canManageStorage && !storageLoading && !storageError && storageByWall.length > 0 && (
              <div className="rounded-xl border border-border/50 p-3 space-y-2">
                <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Storage By Wall (size • last upload)
                </p>
                {storageByWall.map((entry) => {
                  const wallName = walls.find((w) => w.id === entry.wallId)?.name || entry.wallId;
                  return (
                    <div key={entry.wallId} className="flex items-center justify-between text-sm">
                      <span className="text-foreground truncate">{wallName}</span>
                      <span className="text-muted-foreground">
                        {formatBytes(entry.bytes)}
                        {entry.latestTs && (
                          <span className="text-xs text-muted-foreground/70 ml-2">
                            {new Date(entry.latestTs).toLocaleDateString()}
                          </span>
                        )}
                      </span>
                    </div>
                  );
                })}
              </div>
            )}
            {canManageStorage && storageHistory.length > 1 && (
              <div className="rounded-xl border border-border/50 p-3 space-y-2">
                <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Storage Trend
                </p>
                {storageHistory.slice(-7).map((entry) => (
                  <div key={entry.ts} className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">
                      {new Date(entry.ts).toLocaleDateString()}
                    </span>
                    <span className="text-foreground">{formatBytes(entry.bytes)}</span>
                  </div>
                ))}
              </div>
            )}
            {canManageStorage && (
              <button
                onClick={() => {
                  setShowCleanup(true);
                  loadCleanupPreview();
                }}
                className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl bg-destructive/10 text-sm font-medium text-destructive hover:bg-destructive/20 transition-colors"
              >
                Clean Up Storage
              </button>
            )}
            <button
              onClick={handleExportData}
              className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl bg-muted/30 text-sm font-medium text-muted-foreground hover:bg-muted/50 hover:text-foreground transition-colors"
            >
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
              </svg>
              Export Data
            </button>
          </div>
        </section>

        {/* Moderator */}
        {(canManageStorage || !isAuthenticated) && (
          <section>
            <h2 className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-4">
              Admin
            </h2>
            {canManageStorage ? (
              <div className="flex items-center gap-2 text-sm text-amber-600 dark:text-amber-400">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                </svg>
                <span className="font-medium">Moderator mode active</span>
              </div>
            ) : (
              <button
                onClick={() => setShowModLogin(true)}
                className="text-sm text-muted-foreground hover:text-foreground transition-colors"
              >
                Moderator login
              </button>
            )}
          </section>
        )}

        {/* Danger Zone */}
        <section>
          <h2 className="text-xs font-medium text-destructive/70 uppercase tracking-wider mb-4">
            Danger Zone
          </h2>
          <button
            onClick={() => setShowClearData(true)}
            className="text-sm text-destructive hover:text-destructive/80 transition-colors"
          >
            Clear all local data
          </button>
        </section>

        {/* App Info */}
        <section className="pt-8 pb-4 text-center">
          <p className="text-xs text-muted-foreground">Boarded v0.1.2</p>
        </section>
      </main>

      {/* Clear Data Dialog */}
      <Dialog open={showClearData} onOpenChange={setShowClearData}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Clear All Data</DialogTitle>
            <DialogDescription>
              This will remove locally saved routes, walls, drafts, and account caches from this device.
              Data already saved to your account will not be deleted.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowClearData(false)} disabled={isClearingData}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleClearData} disabled={isClearingData}>
              {isClearingData ? 'Clearing...' : 'Clear All Data'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Moderator Login Dialog */}
      <Dialog open={showModLogin} onOpenChange={setShowModLogin}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Moderator Login</DialogTitle>
            <DialogDescription>
              Sign in with a moderator account to access admin controls.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label htmlFor="mod-email">Email</Label>
              <Input
                id="mod-email"
                type="email"
                value={modEmail}
                onChange={(e) => setModEmail(e.target.value)}
                placeholder="moderator@example.com"
                disabled={modLoading}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="mod-password">Password</Label>
              <Input
                id="mod-password"
                type="password"
                value={modPassword}
                onChange={(e) => setModPassword(e.target.value)}
                placeholder="Enter password"
                disabled={modLoading}
              />
            </div>
            {modError && <p className="text-sm text-destructive">{modError}</p>}
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                setShowModLogin(false);
                setModEmail('');
                setModPassword('');
                setModError('');
              }}
              disabled={modLoading}
            >
              Cancel
            </Button>
            <Button
              onClick={handleModLogin}
              disabled={modLoading || !modEmail || !modPassword}
            >
              {modLoading ? 'Signing in...' : 'Sign In'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Storage Cleanup Dialog */}
      <Dialog open={canManageStorage && showCleanup} onOpenChange={setShowCleanup}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Clean Up Storage</DialogTitle>
            <DialogDescription>
              Only previewed images that the server confirms are still unused will be deleted.
              This cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
              Preview
            </p>
            <div className="max-h-48 overflow-y-auto rounded-lg border border-border/50 p-2 text-sm text-muted-foreground">
              {isPreviewLoading ? (
                <p>Loading preview...</p>
              ) : cleanupPreview.length > 0 ? (
                cleanupPreview.map((file) => (
                  <div key={file.id} className="truncate">
                    {file.label} · {formatBytes(file.bytes)}
                  </div>
                ))
              ) : (
                !cleanupError && <p>No unused images older than 7 days.</p>
              )}
            </div>
            {cleanupError && <p className="text-sm text-destructive">{cleanupError}</p>}
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setShowCleanup(false)}
              disabled={isCleaning || isPreviewLoading}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={runStorageCleanup}
              disabled={!canManageStorage || isCleaning || isPreviewLoading || cleanupPreview.length === 0}
            >
              {isCleaning ? 'Cleaning...' : cleanupError ? 'Retry Cleanup' : 'Delete Unused Images'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
