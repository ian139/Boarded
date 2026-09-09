import type { Metadata } from 'next';
import { Feed } from '@/components/boarded/Feed';

export const metadata: Metadata = {
  title: 'Feed — Boarded',
  description: 'Local climbing journal and field dispatches from Stonegate & the crag.',
};

export default function AppPage() {
  return (
    <div data-boarded-path="/app" style={{ display: 'contents' }}>
      <Feed />
    </div>
  );
}
