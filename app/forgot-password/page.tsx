'use client';

import { Suspense, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { AuthHeader } from '@/components/original-board/account/AuthHeader';
import { Button } from '@/components/original-board/ui/button';
import { Input } from '@/components/original-board/ui/input';
import { Label } from '@/components/ui/label';
import { authClient } from '@/lib/api/auth';
import { boardRedirect } from '@/lib/utils';

const linkClass =
  'min-h-[44px] inline-flex items-center justify-center text-primary font-medium hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 rounded-md';

function ForgotPasswordContent() {
  const searchParams = useSearchParams();
  const redirect = boardRedirect(searchParams.get('redirect'), '');
  const loginHref = redirect ? `/login?redirect=${encodeURIComponent(redirect)}` : '/login';
  const resetRedirect = redirect ? `?redirect=${encodeURIComponent(redirect)}` : '';
  const [email, setEmail] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (isLoading) return;
    setError(false);
    setSent(false);
    setIsLoading(true);
    try {
      const result = await authClient.requestPasswordReset({
        email,
        redirectTo: `/reset-password${resetRedirect}`,
      });
      if (result.error) setError(true);
      else setSent(true);
    } catch {
      setError(true);
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="auth-shell min-h-dvh flex flex-col">
      <AuthHeader title="Forgot Password" backHref={loginHref} backLabel="Back to log in" />
      <main className="flex-1 px-4 pb-12 flex items-center justify-center">
        <form onSubmit={handleSubmit} className="auth-card w-full space-y-5 max-w-md">
          <div className="space-y-2">
            <Label htmlFor="forgot-email">Email</Label>
            <Input
              id="forgot-email"
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="you@example.com"
              required
              disabled={isLoading}
              autoComplete="email"
            />
          </div>

          {error && (
            <p role="alert" className="text-sm text-destructive">
              We couldn&apos;t process that request right now. Please try again.
            </p>
          )}
          {sent && (
            <p role="status" className="text-sm text-muted-foreground">
              If an account uses this email, a reset link is on its way.
            </p>
          )}

          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading ? 'Sending…' : 'Send reset link'}
          </Button>

          <p className="text-center text-sm text-muted-foreground">
            Remember your password?{' '}
            <Link href={loginHref} className={linkClass}>
              Log in
            </Link>
          </p>
        </form>
      </main>
    </div>
  );
}

export default function ForgotPasswordPage() {
  return (
    <Suspense fallback={<div className="auth-shell min-h-dvh flex items-center justify-center" />}>
      <ForgotPasswordContent />
    </Suspense>
  );
}
