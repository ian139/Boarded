'use client';

import { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { AuthHeader } from '@/components/original-board/account/AuthHeader';
import { LoginForm } from '@/components/original-board/account/LoginForm';
import { boardRedirect } from '@/lib/utils';

function LoginContent() {
  const searchParams = useSearchParams();
  const redirect = searchParams.get('redirect');
  const backHref = boardRedirect(redirect, '/settings');

  return (
    <div className="auth-shell min-h-dvh flex flex-col">
      <AuthHeader title="Log In" backHref={backHref} backLabel="Back to settings" />
      <main className="flex-1 px-4 pb-12 flex items-center justify-center">
        <LoginForm />
      </main>
    </div>
  );
}

export default function BoardLoginPage() {
  return (
    <Suspense fallback={<div className="auth-shell min-h-dvh flex items-center justify-center" />}>
      <LoginContent />
    </Suspense>
  );
}
