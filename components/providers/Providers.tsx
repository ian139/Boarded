'use client';

import { usePathname } from 'next/navigation';
import { AuthProvider } from './AuthProvider';

export function Providers({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isAppRoute = pathname === '/app' || pathname?.startsWith('/app/');

  if (isAppRoute) {
    return <>{children}</>;
  }

  return <AuthProvider>{children}</AuthProvider>;
}
