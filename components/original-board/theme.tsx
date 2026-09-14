'use client';

/**
 * Standalone board theme, persisted with the existing board preference key.
 * The wrapper and portal roots carry the same scope so dialogs and selects
 * resolve the warm palette consistently. A single root Toaster consumes the
 * shared toast store; board-original.css supplies its matching theme.
 */

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

export type BoardTheme = 'light' | 'dark' | 'system';
export type BoardResolvedTheme = 'light' | 'dark';

const STORAGE_KEY = 'boarded-board-theme';

interface BoardThemeContextValue {
  theme: BoardTheme;
  resolvedTheme: BoardResolvedTheme;
  setTheme: (theme: BoardTheme) => void;
}

const BoardThemeContext = createContext<BoardThemeContextValue>({
  theme: 'system',
  resolvedTheme: 'light',
  setTheme: () => {},
});

export function useBoardTheme() {
  return useContext(BoardThemeContext);
}

/** Class list that scopes the restored board tokens. Portals re-apply it. */
export function useBoardScopeClass(): string {
  const { resolvedTheme } = useBoardTheme();
  return resolvedTheme === 'dark' ? 'board-original dark' : 'board-original';
}


export function BoardThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<BoardTheme>('system');
  const [systemDark, setSystemDark] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored === 'light' || stored === 'dark' || stored === 'system') {
        setThemeState(stored);
      }
    } catch {
      // Private browsing: fall back to system preference.
    }
    setSystemDark(window.matchMedia('(prefers-color-scheme: dark)').matches);
    setMounted(true);
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = (event: MediaQueryListEvent) => setSystemDark(event.matches);
    media.addEventListener('change', onChange);
    return () => media.removeEventListener('change', onChange);
  }, []);

  const resolvedTheme: BoardResolvedTheme = mounted
    ? theme === 'system'
      ? systemDark
        ? 'dark'
        : 'light'
      : theme
    : 'light';

  const setTheme = (next: BoardTheme) => {
    setThemeState(next);
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // Ignore persistence failures.
    }
  };

  const value = useMemo(
    () => ({ theme, resolvedTheme, setTheme }),
    [theme, resolvedTheme]
  );
  return (
    <BoardThemeContext.Provider value={value}>
      <div
        className={
          resolvedTheme === 'dark' ? 'board-root board-original dark' : 'board-root board-original'
        }
      >
        {children}
      </div>
    </BoardThemeContext.Provider>
  );
}
