'use client';

import { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { AuthHeader } from '@/components/original-board/account/AuthHeader';
import { SignupForm } from '@/components/original-board/account/SignupForm';
import { boardRedirect } from '@/lib/utils';

function SignupContent() {
  const searchParams = useSearchParams();
  const redirect = searchParams.get('redirect');
  const backHref = boardRedirect(redirect, '/settings');

  return (
    <div className="auth-shell min-h-dvh flex flex-col">
      <AuthHeader title="Sign Up" backHref={backHref} backLabel="Back to settings" />
      <main className="flex-1 px-4 pb-12 flex items-center justify-center">
        <SignupForm />
      </main>
    </div>
  );
}

export default function BoardSignupPage() {
  return (
    <Suspense fallback={<div className="auth-shell min-h-dvh flex items-center justify-center" />}>
      <SignupContent />
    </Suspense>
  );
}
