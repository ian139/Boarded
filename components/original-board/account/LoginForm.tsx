'use client';

import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { useUserStore } from '@/lib/stores/user-store';
import { Button } from '@/components/original-board/ui/button';
import { Input } from '@/components/original-board/ui/input';
import { Label } from '@/components/ui/label';
import { toast } from 'sonner';
import { boardRedirect } from '@/lib/utils';
import { authClient } from '@/lib/api/auth';

export function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { login, isAuthenticated } = useUserStore();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isSendingVerification, setIsSendingVerification] = useState(false);
  const [verificationStatus, setVerificationStatus] = useState<string | null>(null);
  const emailInput = useRef<HTMLInputElement>(null);
  const isBusy = isLoading || isSendingVerification;

  const redirectParam = boardRedirect(searchParams.get('redirect'), '');
  const targetUrl = redirectParam || '/profile';
  const confirmationError = searchParams.has('error')
    ? 'This confirmation link could not be used. Enter your email and request a new confirmation link below.'
    : null;

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated) {
      router.push(targetUrl);
    }
  }, [isAuthenticated, router, targetUrl]);

  if (isAuthenticated) {
    return null;
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (isBusy) return;
    setError(null);
    setVerificationStatus(null);
    setIsLoading(true);

    try {
      const result = await login(email, password);
      if (result.success) {
        toast.success('Welcome back!');
        router.push(targetUrl);
      } else {
        setError(result.error || 'Login failed');
      }
    } catch {
      setError('Unable to log in right now. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const signupHref = redirectParam
    ? `/signup?redirect=${encodeURIComponent(redirectParam)}`
    : '/signup';
  const loginHref = redirectParam
    ? `/login?redirect=${encodeURIComponent(redirectParam)}`
    : '/login';
  const forgotHref = redirectParam
    ? `/forgot-password?redirect=${encodeURIComponent(redirectParam)}`
    : '/forgot-password';

  const handleResendVerification = async () => {
    if (isBusy || !emailInput.current?.reportValidity()) return;
    setError(null);
    setVerificationStatus(null);
    setIsSendingVerification(true);
    try {
      const result = await authClient.sendVerificationEmail({ email, callbackURL: loginHref });
      if (result.error) {
        setError('Unable to send a confirmation email right now. Please try again later.');
      } else {
        setVerificationStatus('If this email needs confirmation, a new confirmation link is on its way. Check your inbox and spam folder.');
      }
    } catch {
      setError('Unable to send a confirmation email right now. Please try again later.');
    } finally {
      setIsSendingVerification(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="auth-card w-full space-y-5 max-w-md">
      <div className="space-y-2">
        <Label htmlFor="email">Email</Label>
        <Input
          ref={emailInput}
          id="email"
          type="email"
          value={email}
          onChange={(e) => {
            setEmail(e.target.value);
            setVerificationStatus(null);
          }}
          placeholder="you@example.com"
          required
          disabled={isBusy}
          autoComplete="email"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="password">Password</Label>
        <Input
          id="password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="Enter your password"
          required
          disabled={isBusy}
          autoComplete="current-password"
        />
      </div>

      <Link href={forgotHref} className="inline-flex min-h-11 items-center text-sm font-medium text-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
        Forgot password?
      </Link>

      {(error || confirmationError) && (
        <p role="alert" className="text-sm text-destructive">{error || confirmationError}</p>
      )}
      {verificationStatus && (
        <p role="status" className="text-sm text-muted-foreground">{verificationStatus}</p>
      )}

      <Button
        type="submit"
        className="w-full"
        disabled={isBusy}
      >
        {isLoading ? 'Logging in...' : 'Log In'}
      </Button>

      <div className="space-y-2">
        <p className="text-sm text-muted-foreground">Email not confirmed? Enter your email above to request a new link.</p>
        <Button type="button" variant="outline" className="w-full min-h-11" disabled={isBusy} onClick={handleResendVerification}>
          {isSendingVerification ? 'Sending...' : 'Resend confirmation email'}
        </Button>
      </div>

      <p className="text-center text-sm text-muted-foreground">
        Don&apos;t have an account?{' '}
        <Link href={signupHref} className="text-primary font-medium hover:underline">
          Sign Up
        </Link>
      </p>
    </form>
  );
}
