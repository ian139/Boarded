import type { Metadata } from 'next';
import './boarded.css';
import { Shell } from '@/components/boarded/Shell';

export const metadata: Metadata = {
  title: 'Boarded — Climbing Journal',
  description: 'Editorial rock climbing journal and field instrument for tracking sends and routes.',
};

export default function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <Shell>{children}</Shell>;
}
