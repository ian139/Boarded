'use client';

import { useEffect, useId, useRef, useState, type ChangeEvent, type FormEvent } from 'react';
import Image from 'next/image';
import { Camera, LoaderCircle, X } from 'lucide-react';
import { useUserStore } from '@/lib/stores/user-store';
import { Button } from '@/components/original-board/ui/button';
import { Input } from '@/components/original-board/ui/input';
import { Label } from '@/components/ui/label';
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/original-board/ui/dialog';

const focusRing = 'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background motion-reduce:transition-none';
const usernameErrors = {
  conflict: 'That username is already taken. Try another one.',
  invalid: 'Use 1–80 letters, numbers, underscores or hyphens. No spaces or @.',
  failed: 'Unable to save your username. Please try again.',
  stale: 'Your account session changed. Reopen your profile to try again.',
};

export function ChangeProfileDialog() {
  const { user, profile, updateProfile, uploadAvatar } = useUserStore();
  const [open, setOpen] = useState(false);
  const [username, setUsername] = useState('');
  const [usernameError, setUsernameError] = useState('');
  const [avatarError, setAvatarError] = useState('');
  const [status, setStatus] = useState('');
  const [busy, setBusy] = useState<'avatar' | 'username' | null>(null);
  const pending = useRef(false);
  const mounted = useRef(true);
  const fileInput = useRef<HTMLInputElement>(null);
  const usernameInput = useRef<HTMLInputElement>(null);
  const id = useId();

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  const changeOpen = (next: boolean) => {
    if (pending.current) return;
    if (next) {
      setUsername(profile?.username ?? '');
      setUsernameError('');
      setAvatarError('');
      setStatus('');
    }
    setOpen(next);
  };

  const saveUsername = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (pending.current || username === profile?.username) return;
    setStatus('');
    if (!/^[A-Za-z0-9_-]{1,80}$/.test(username)) {
      setUsernameError(usernameErrors.invalid);
      usernameInput.current?.focus();
      return;
    }
    pending.current = true;
    setBusy('username');
    setUsernameError('');
    try {
      const result = await updateProfile({ username });
      if (!mounted.current) return;
      if (result.ok) {
        setStatus('Username saved.');
      } else {
        setUsernameError(usernameErrors[result.error]);
        usernameInput.current?.focus();
      }
    } finally {
      pending.current = false;
      if (mounted.current) setBusy(null);
    }
  };

  const selectAvatar = async (event: ChangeEvent<HTMLInputElement>) => {
    const input = event.currentTarget;
    const file = input.files?.[0];
    // Clear even a failed selection so the same file can be chosen again.
    input.value = '';
    if (!file || pending.current) return;
    setAvatarError('');
    setStatus('');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      setAvatarError('Choose a JPEG, PNG or WebP image.');
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setAvatarError('Choose an image no larger than 10 MiB.');
      return;
    }
    pending.current = true;
    setBusy('avatar');
    try {
      const avatarUrl = await uploadAvatar(file);
      if (!mounted.current) return;
      if (avatarUrl) setStatus('Photo updated.');
      else setAvatarError('Unable to update your photo. Please try again.');
    } finally {
      pending.current = false;
      if (mounted.current) setBusy(null);
    }
  };

  return (
    <Dialog open={open} onOpenChange={changeOpen}>
      <DialogTrigger asChild>
        <Button type="button" variant="outline" disabled={!profile} className={`min-h-11 h-auto whitespace-normal bg-card px-3 py-2 text-xs text-primary ${focusRing}`}>
          Change profile
        </Button>
      </DialogTrigger>
      <DialogContent
        showCloseButton={false}
        className="w-[calc(100%_-_2.5rem)] max-w-[480px] sm:max-w-[480px] max-h-[calc(100dvh_-_2.5rem)] gap-6 overflow-y-auto rounded-3xl bg-card p-5 text-foreground backdrop-blur-none sm:p-6 motion-reduce:animate-none motion-reduce:transition-none"
        onEscapeKeyDown={(event) => { if (pending.current) event.preventDefault(); }}
        onInteractOutside={(event) => { if (pending.current) event.preventDefault(); }}
      >
        <DialogHeader className="pr-11 text-left">
          <DialogTitle>Change profile</DialogTitle>
          <DialogDescription>Make your profile feel like you.</DialogDescription>
        </DialogHeader>
        <DialogClose asChild>
          <Button type="button" variant="ghost" size="icon" disabled={Boolean(busy)} aria-label="Close profile editor" className={`absolute right-3 top-3 size-11 ${focusRing}`}>
            <X aria-hidden="true" />
          </Button>
        </DialogClose>

        <section aria-labelledby={`${id}-photo-label`} className="flex flex-wrap items-center gap-4 rounded-2xl border border-border bg-background p-4">
          <button
            type="button"
            onClick={() => fileInput.current?.click()}
            disabled={Boolean(busy)}
            aria-label="Upload profile photo"
            aria-describedby={`${id}-photo-help${avatarError ? ` ${id}-photo-error` : ''}`}
            aria-busy={busy === 'avatar'}
            className={`relative size-20 shrink-0 rounded-full border border-border bg-primary/10 outline-none disabled:cursor-not-allowed disabled:opacity-60 ${focusRing}`}
          >
            {profile?.avatar_url ? (
              <Image unoptimized src={profile.avatar_url} alt="" width={80} height={80} className="size-full rounded-full object-cover" />
            ) : (
              <span className="text-3xl font-semibold text-primary" aria-hidden="true">{(user?.displayName || 'Climber').charAt(0).toUpperCase()}</span>
            )}
            <span className="absolute -bottom-1 -right-1 flex size-8 items-center justify-center rounded-full border-2 border-card bg-primary text-primary-foreground">
              {busy === 'avatar' ? <LoaderCircle className="size-4 animate-spin motion-reduce:animate-none" aria-hidden="true" /> : <Camera className="size-4" aria-hidden="true" />}
            </span>
          </button>
          <div className="min-w-0 flex-1 basis-36 space-y-1">
            <h3 id={`${id}-photo-label`} className="text-sm font-semibold">Profile photo</h3>
            <p className="text-sm text-muted-foreground">Click your photo to upload.</p>
            <p id={`${id}-photo-help`} className="text-xs leading-relaxed text-muted-foreground">JPEG, PNG or WebP · Up to 10 MiB<br />Your photo saves automatically.</p>
          </div>
          <input ref={fileInput} type="file" accept="image/jpeg,image/png,image/webp" className="hidden" onChange={selectAvatar} disabled={Boolean(busy)} aria-label="Choose profile photo" />
          {avatarError && <p id={`${id}-photo-error`} role="alert" className="w-full text-sm text-destructive">{avatarError}</p>}
        </section>

        <form onSubmit={saveUsername} noValidate className="min-w-0 space-y-5">
          <div className="space-y-2">
            <Label htmlFor={`${id}-username`}>Username</Label>
            <Input
              ref={usernameInput}
              id={`${id}-username`}
              name="username"
              value={username}
              onChange={(event) => { setUsername(event.target.value); setUsernameError(''); setStatus(''); }}
              readOnly={Boolean(busy)}
              autoComplete="off"
              autoCapitalize="none"
              autoCorrect="off"
              spellCheck={false}
              maxLength={80}
              aria-invalid={Boolean(usernameError)}
              aria-describedby={`${id}-username-help${usernameError ? ` ${id}-username-error` : ''}`}
              className={`h-[52px] bg-background text-base dark:bg-background md:text-base ${focusRing}`}
            />
            <p id={`${id}-username-help`} className="text-xs leading-relaxed text-muted-foreground">1–80 letters, numbers, underscores or hyphens. No spaces or @.</p>
            {usernameError && <p id={`${id}-username-error`} role="alert" className="text-sm text-destructive">{usernameError}</p>}
          </div>
          <p role="status" aria-live="polite" className="min-h-5 text-sm text-muted-foreground">
            {busy === 'avatar' ? 'Uploading photo…' : busy === 'username' ? 'Saving username…' : status}
          </p>
          <DialogFooter className="gap-3 border-t border-border pt-5">
            <DialogClose asChild>
              <Button type="button" variant="outline" disabled={Boolean(busy)} className={`min-h-11 h-auto whitespace-normal bg-background py-2 ${focusRing}`}>Done</Button>
            </DialogClose>
            <Button type="submit" disabled={Boolean(busy) || username === profile?.username} aria-busy={busy === 'username'} className={`min-h-11 h-auto whitespace-normal py-2 ${focusRing}`}>
              {busy === 'username' ? 'Saving…' : 'Save username'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
