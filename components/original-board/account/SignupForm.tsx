'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { useUserStore } from '@/lib/stores/user-store';
import { Button } from '@/components/original-board/ui/button';
import { Input } from '@/components/original-board/ui/input';
import { Label } from '@/components/ui/label';
import { toast } from 'sonner';
import { boardRedirect } from '@/lib/utils';
import { authClient } from '@/lib/api/auth';

export function SignupForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { signup, isAuthenticated } = useUserStore();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [requiresConfirmation, setRequiresConfirmation] = useState(false);
  const [verificationStatus, setVerificationStatus] = useState<string | null>(null);

  const redirectParam = boardRedirect(searchParams.get('redirect'), '');
  const targetUrl = redirectParam || '/profile';

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
    if (isLoading) return;
    setError(null);

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    if (password.length < 8) {
      setError('Password must be at least 8 characters');
      return;
    }

    setIsLoading(true);

    try {
      const result = await signup(email, password, displayName || undefined, loginHref);
      if (result.success) {
        if (result.requiresConfirmation) {
          setRequiresConfirmation(true);
          setPassword('');
          setConfirmPassword('');
        } else {
          toast.success('Account created!');
          router.push(targetUrl);
        }
      } else {
        setError(result.error || 'Signup failed');
      }
    } catch {
      setError('Unable to create an account right now. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const loginHref = redirectParam
    ? `/login?redirect=${encodeURIComponent(redirectParam)}`
    : '/login';

  const handleResendVerification = async () => {
    if (isLoading) return;
    setError(null);
    setVerificationStatus(null);
    setIsLoading(true);
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
      setIsLoading(false);
    }
  };

  if (requiresConfirmation) {
    return (
      <section className="auth-card w-full space-y-5 max-w-md" aria-labelledby="check-email-title">
        <h1 id="check-email-title" className="text-xl font-semibold">Check your email</h1>
        <p role="status" className="text-sm text-muted-foreground">
          Confirm your email address using the link in your inbox, then return to log in. You are not signed in yet.
        </p>
        {error && <p role="alert" className="text-sm text-destructive">{error}</p>}
        {verificationStatus && <p role="status" className="text-sm text-muted-foreground">{verificationStatus}</p>}
        <Button type="button" variant="outline" className="w-full min-h-11" disabled={isLoading} onClick={handleResendVerification}>
          {isLoading ? 'Sending...' : 'Resend confirmation email'}
        </Button>
        <Link href={loginHref} className="inline-flex min-h-11 items-center text-sm font-medium text-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
          Return to Log In
        </Link>
      </section>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="auth-card w-full space-y-5 max-w-md">
      <div className="space-y-2">
        <Label htmlFor="email">Email</Label>
        <Input
          id="email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@example.com"
          required
          disabled={isLoading}
          autoComplete="email"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="displayName">Display Name (optional)</Label>
        <Input
          id="displayName"
          type="text"
          value={displayName}
          onChange={(e) => setDisplayName(e.target.value)}
          placeholder="Your name"
          disabled={isLoading}
          autoComplete="name"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="password">Password</Label>
        <Input
          id="password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="At least 8 characters"
          minLength={8}
          required
          disabled={isLoading}
          autoComplete="new-password"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="confirmPassword">Confirm Password</Label>
        <Input
          id="confirmPassword"
          type="password"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          placeholder="Confirm your password"
          minLength={8}
          required
          disabled={isLoading}
          autoComplete="new-password"
        />
      </div>

      {error && (
        <p role="alert" className="text-sm text-destructive">{error}</p>
      )}

      <Button
        type="submit"
        className="w-full"
        disabled={isLoading}
      >
        {isLoading ? 'Creating account...' : 'Create Account'}
      </Button>

      <p className="text-center text-sm text-muted-foreground">
        Already have an account?{' '}
        <Link href={loginHref} className="text-primary font-medium hover:underline">
          Log In
        </Link>
      </p>
    </form>
  );
}
