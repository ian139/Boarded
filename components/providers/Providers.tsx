'use client';

import dynamic from 'next/dynamic';
import { usePathname } from 'next/navigation';

// Dynamic boundary (F9): the auth/supabase chunk is loaded only on routes that
// actually use auth state; journal (/app*) and marketing (/) routes keep it out
// of their module graph entirely.
const AuthProvider = dynamic(() => import('./AuthProvider').then((m) => m.AuthProvider));

// Route prefixes whose surfaces consume useUserStore (studio, auth, share
// viewer). initializeAuth runs only here (F15) so the landing page and the
// journal skip the full auth reconciliation network work.
const AUTH_INITIALIZED_PREFIXES = [
  '/board',
  '/editor',
  '/login',
  '/profile',
  '/settings',
  '/share',
  '/signup',
];

function needsAuthProvider(pathname: string | null): boolean {
  if (!pathname) return true;
  return AUTH_INITIALIZED_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`)
  );
}

export function Providers({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  if (!needsAuthProvider(pathname)) {
    return <>{children}</>;
  }

  return <AuthProvider>{children}</AuthProvider>;
}
