import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Boarded — Keep the line.',
  description: 'A quiet climbing journal built around movement, effort, and return.',
};

export default function MarketingLanding() {
  return (
    <main id="main-content" className="min-h-screen bg-[#0A0B10] text-[#F4F2EB] p-8">
      <h1 className="text-3xl font-serif italic">Keep the line.</h1>
    </main>
  );
}
