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

type ResetError = 'invalid' | 'service' | null;

function ResetPasswordContent() {
  const searchParams = useSearchParams();
  const token = searchParams.get('token');
  const callbackError = searchParams.get('error');
  const redirect = boardRedirect(searchParams.get('redirect'), '');
  const loginHref = redirect ? `/login?redirect=${encodeURIComponent(redirect)}` : '/login';
  const forgotHref = redirect ? `/forgot-password?redirect=${encodeURIComponent(redirect)}` : '/forgot-password';
  const hasInvalidLink = !token || Boolean(callbackError);
  const [newPassword, setNewPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [validationError, setValidationError] = useState<string | null>(null);
  const [resetError, setResetError] = useState<ResetError>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (isLoading || hasInvalidLink || !token) return;
    setValidationError(null);
    setResetError(null);
    setSuccess(false);
    if (newPassword.length < 8) {
      setValidationError('Password must be at least 8 characters.');
      return;
    }
    if (newPassword !== confirmation) {
      setValidationError('Passwords do not match.');
      return;
    }

    setIsLoading(true);
    try {
      const result = await authClient.resetPassword({ newPassword, token });
      if (result.error) {
        setResetError(result.error.code === 'INVALID_TOKEN' ? 'invalid' : 'service');
      } else {
        setSuccess(true);
        setNewPassword('');
        setConfirmation('');
      }
    } catch {
      setResetError('service');
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="auth-shell min-h-dvh flex flex-col">
      <AuthHeader title="Reset Password" backHref={loginHref} backLabel="Back to log in" />
      <main className="flex-1 px-4 pb-12 flex items-center justify-center">
        <section className="auth-card w-full space-y-5 max-w-md" aria-live="polite">
          {hasInvalidLink ? (
            <>
              <div role="alert" className="text-sm text-destructive">
                This password reset link is missing, invalid, or expired. Request a new link to continue.
              </div>
              <Link href={forgotHref} className={`${linkClass} w-full`}>
                Request a new reset link
              </Link>
            </>
          ) : success ? (
            <>
              <p role="status" className="text-sm text-muted-foreground">
                Your password has been reset. You can now log in with your new password.
              </p>
              <Link href={loginHref} className={`${linkClass} w-full`}>
                Log in
              </Link>
            </>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-5">
              <div className="space-y-2">
                <Label htmlFor="new-password">New password</Label>
                <Input
                  id="new-password"
                  type="password"
                  value={newPassword}
                  onChange={(event) => setNewPassword(event.target.value)}
                  required
                  minLength={8}
                  disabled={isLoading}
                  autoComplete="new-password"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="confirm-password">Confirm new password</Label>
                <Input
                  id="confirm-password"
                  type="password"
                  value={confirmation}
                  onChange={(event) => setConfirmation(event.target.value)}
                  required
                  minLength={8}
                  disabled={isLoading}
                  autoComplete="new-password"
                />
              </div>

              {(validationError || resetError) && (
                <div role="alert" className="text-sm text-destructive">
                  {validationError ||
                    (resetError === 'invalid'
                      ? 'This reset link is invalid or expired. Request a new link to continue.'
                      : 'We couldn’t reset your password right now. Please try again.')}
                </div>
              )}
              {resetError && (
                <Link href={forgotHref} className={`${linkClass} w-full`}>
                  Request a new reset link
                </Link>
              )}

              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? 'Resetting…' : resetError === 'service' ? 'Try again' : 'Reset password'}
              </Button>
            </form>
          )}
        </section>
      </main>
    </div>
  );
}

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={<div className="auth-shell min-h-dvh flex items-center justify-center" />}>
      <ResetPasswordContent />
    </Suspense>
  );
}
