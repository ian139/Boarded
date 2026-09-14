import Link from 'next/link';

interface AuthHeaderProps {
  title: string;
  backHref?: string;
  backLabel?: string;
}

export function AuthHeader({
  title,
  backHref = '/',
  backLabel = 'Back to home',
}: AuthHeaderProps) {
  return (
    <header className="page-frame px-4 md:px-8 pt-6 pb-5">
      <div className="flex items-center gap-3">
        <Link
          href={backHref}
          aria-label={backLabel}
          className="size-10 rounded-xl bg-card border border-border flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
          </svg>
        </Link>
        <h1 className="text-xl font-bold">{title}</h1>
      </div>
    </header>
  );
}
