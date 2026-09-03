import type { Metadata } from 'next';
import Link from 'next/link';
import { PhotoWallHero } from '@/components/landing/PhotoWallHero';

export const metadata: Metadata = {
  title: 'Boarded — Keep the line.',
  description: 'A quiet climbing journal built around movement, effort, and return.',
};

export default function MarketingLanding() {
  return (
    <div className="min-h-screen bg-[#0A0B10] text-[#F4F2EB] flex flex-col selection:bg-[rgba(50,213,131,0.14)]">
      {/* 1. Skip link to #main-content */}
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-[#0A0B10] focus:text-[#32D583] focus:border focus:border-[#32D583] focus:rounded-lg focus:outline-none"
      >
        Skip to main content
      </a>

      {/* 2. Normal-flow header > nav */}
      <header className="w-full border-b border-[rgba(244,242,235,0.08)] bg-[#0A0B10]">
        <nav
          aria-label="Primary navigation"
          className="landing-frame flex items-center justify-between h-20"
        >
          <div className="flex items-center gap-10">
            <Link
              href="/"
              className="landing-touch-link landing-font-display text-2xl md:text-3xl text-[#F4F2EB] tracking-tight focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#32D583]"
            >
              Boarded
            </Link>
            {/* Desktop anchors hidden below 600px */}
            <div className="hidden sm:flex items-center gap-8">
              <a
                href="#approach"
                className="landing-touch-link text-sm font-medium text-[rgba(244,242,235,0.64)] hover:text-[#F4F2EB] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#32D583] rounded-sm"
              >
                Approach
              </a>
              <a
                href="#practice"
                className="landing-touch-link text-sm font-medium text-[rgba(244,242,235,0.64)] hover:text-[#F4F2EB] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#32D583] rounded-sm"
              >
                Practice
              </a>
            </div>
          </div>

          <div className="flex items-center gap-4 sm:gap-6">
            <Link
              href="/login"
              className="landing-touch-link text-sm font-medium text-[rgba(244,242,235,0.64)] hover:text-[#F4F2EB] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#32D583] rounded-sm"
            >
              Sign in
            </Link>
            <Link href="/app" className="landing-cta-primary text-sm px-5 py-2.5">
              Open Boarded
            </Link>
          </div>
        </nav>
      </header>

      {/* Main content */}
      <main id="main-content" className="flex-1">
        {/* 3. Hero section */}
        <section
          aria-labelledby="hero-title"
          className="landing-frame py-12 sm:py-16 md:py-24"
        >
          <div className="grid grid-cols-1 md:grid-cols-12 gap-8 md:gap-12 items-center">
            {/* Copy spans 5 columns at >=900px, stacks above at <900px */}
            <div className="md:col-span-5 flex flex-col items-start gap-6">
              <p className="text-xs font-semibold tracking-[0.12em] text-[#32D583] uppercase">
                A climbing journal
              </p>
              <h1
                id="hero-title"
                className="landing-font-display text-[48px] leading-[48px] md:text-[64px] md:leading-[1] text-[#F4F2EB] tracking-tight"
              >
                Keep the line.
              </h1>
              <p className="text-base sm:text-lg text-[rgba(244,242,235,0.64)] leading-relaxed max-w-[42ch]">
                A quiet place for the movement, effort, and return that make climbing yours.
              </p>
              <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-4 pt-2 w-full sm:w-auto">
                <Link href="/app" className="landing-cta-primary">
                  Enter Boarded
                </Link>
                <a href="#approach" className="landing-cta-secondary">
                  Our approach
                </a>
              </div>
            </div>

            {/* Visual stage spans 7 columns at >=900px, sibling right-side figure */}
            <div className="md:col-span-7 w-full flex justify-center items-center">
              <figure className="w-full max-w-[680px]">
                <PhotoWallHero />
              </figure>
            </div>
          </div>
        </section>

        {/* 4. Manifesto section */}
        <section
          id="approach"
          aria-labelledby="approach-title"
          className="w-full border-t border-[rgba(244,242,235,0.08)] py-16 sm:py-20 md:py-24"
        >
          <div className="landing-frame">
            <div className="max-w-[720px] flex flex-col items-start gap-4">
              <p className="text-xs font-semibold tracking-[0.12em] text-[#32D583] uppercase">
                The practice
              </p>
              <h2
                id="approach-title"
                className="landing-font-display text-3xl sm:text-4xl md:text-5xl text-[#F4F2EB] tracking-tight"
              >
                The wall changes. Your line stays.
              </h2>
              <p className="text-base sm:text-lg md:text-xl text-[rgba(244,242,235,0.64)] leading-relaxed pt-2">
                Climbing is repetition, attention, and the courage to try again. Boarded is built in that spirit.
              </p>
            </div>
          </div>
        </section>

        {/* 5. Ordered principles list */}
        <section
          id="practice"
          aria-labelledby="practice-title"
          className="w-full border-t border-[rgba(244,242,235,0.08)] py-16 sm:py-20 md:py-24"
        >
          <div className="landing-frame">
            <h2 id="practice-title" className="sr-only">
              Core Principles
            </h2>
            <ol className="flex flex-col md:flex-row justify-between gap-8 md:gap-12 list-decimal list-inside m-0 p-0 text-[#F4F2EB] marker:text-[#32D583] marker:font-semibold">
              <li className="text-base sm:text-lg leading-relaxed">
                <span className="font-semibold text-[#F4F2EB]">Notice the move</span>
                <span className="text-[rgba(244,242,235,0.64)]"> — Presence before progress.</span>
              </li>
              <li className="text-base sm:text-lg leading-relaxed">
                <span className="font-semibold text-[#F4F2EB]">Trust the process</span>
                <span className="text-[rgba(244,242,235,0.64)]"> — One attempt at a time.</span>
              </li>
              <li className="text-base sm:text-lg leading-relaxed">
                <span className="font-semibold text-[#F4F2EB]">Return with intent</span>
                <span className="text-[rgba(244,242,235,0.64)]"> — The next line starts here.</span>
              </li>
            </ol>
          </div>
        </section>

        {/* 6. Closing CTA */}
        <section aria-labelledby="closing-title" className="landing-frame my-12 sm:my-16 md:my-20">
          <div className="rounded-2xl bg-[#0D0F14] border border-[rgba(244,242,235,0.18)] p-8 sm:p-12 md:p-16">
            <div className="max-w-[640px] flex flex-col items-start gap-4">
              <h2
                id="closing-title"
                className="landing-font-display text-3xl sm:text-4xl md:text-5xl text-[#F4F2EB] tracking-tight"
              >
                For the climb ahead.
              </h2>
              <p className="text-base sm:text-lg text-[rgba(244,242,235,0.64)] leading-relaxed">
                Stay close to the wall. Keep moving.
              </p>
              <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-4 pt-4 w-full sm:w-auto">
                <Link href="/app" className="landing-cta-primary">
                  Open Boarded
                </Link>
                <Link href="/login" className="landing-cta-secondary">
                  Sign in
                </Link>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* 7. Footer */}
      <footer className="w-full border-t border-[rgba(244,242,235,0.08)] py-10 bg-[#0A0B10]">
        <div className="landing-frame flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
          <div className="flex flex-col sm:flex-row items-baseline gap-2 sm:gap-6">
            <span className="landing-font-display text-xl text-[#F4F2EB] tracking-tight">
              Boarded
            </span>
            <span className="text-sm text-[rgba(244,242,235,0.64)]">
              A climbing journal.
            </span>
          </div>
          <Link
            href="/login"
            className="landing-touch-link text-sm font-medium text-[rgba(244,242,235,0.64)] hover:text-[#F4F2EB] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#32D583] rounded-sm"
          >
            Sign in
          </Link>
        </div>
      </footer>
    </div>
  );
}
