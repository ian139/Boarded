import type { Metadata, Viewport } from 'next';
import './board-original.css';
import { BoardThemeProvider } from '@/components/original-board/theme';
import { BottomNav } from '@/components/original-board/shared/BottomNav';

/**
 * Route-local layout for /board.
 *
 * Isolation notes:
 * - The root layout forces `class="dark"` on <html> and a dark-only token set;
 *   this route restores the 668e334 warm palette via the scoped
 *   `.board-original` wrapper (see board-original.css) without mutating any
 *   global CSS.
 * - Theme state is system-initialized and persisted route-locally
 *   (BoardThemeProvider); the global next-themes provider is not used.
 * - Historical viewport theme colors from 668e334 (light #f7f3ea / dark #1b1a17).
 */
export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#f7f3ea' },
    { media: '(prefers-color-scheme: dark)', color: '#1b1a17' },
  ],
};

/** Restored-era document metadata (verbatim from 668e334 app/layout.tsx). */
export const metadata: Metadata = {
  title: 'Boarded - Digital Route Setter',
  description: 'Document and share your climbing routes',
};

export default function BoardLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <BoardThemeProvider>
      {children}
      <BottomNav />
    </BoardThemeProvider>
  );
}
