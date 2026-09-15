'use client';

import { useEffect } from 'react';
import { useUserStore } from '@/lib/stores/user-store';
import { authClient } from '@/lib/api/auth';

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const initializeAuth = useUserStore((state) => state.initializeAuth);
  const session = authClient.useSession();

  useEffect(() => {
    // Better Auth keeps both user.id and isPending stable during signed-in refreshes.
    if (!session.isPending && !session.isRefetching) void initializeAuth();
  }, [initializeAuth, session.isPending, session.isRefetching, session.data?.user.id]);

  return <>{children}</>;
}
