import type { Metadata } from 'next';
import Link from 'next/link';
import { ClimbingWallExperience } from '@/components/landing/ClimbingWallExperience';
import './landing.css';

export const metadata: Metadata = {
  title: 'Boarded — A little more within reach.',
  description: 'Your wall. Your next idea. Create, document, and share climbing routes with Boarded, a home for your climbing practice.',
};

function Arrow({ down = false }: { down?: boolean }) {
  return <svg viewBox="0 0 24 24" fill="none" aria-hidden="true" className={down ? 'landing-arrow landing-arrow-down' : 'landing-arrow'}><path d="M4 12h15m-6-6 6 6-6 6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

export default function MarketingLanding() {
  return (
    <div className="landing">
      <div id="landing-scene-host" aria-hidden="true" />
      <a href="#main-content" className="landing-skip">Skip to main content</a>
      <header className="landing-header">
        <nav aria-label="Primary navigation" className="landing-nav">
          <Link href="/" className="landing-wordmark" aria-label="Boarded home">Boarded</Link>
          <div className="landing-nav-middle"><a href="#approach">The idea</a><a href="#practice">The practice</a></div>
          <div className="landing-nav-actions"><Link href="/login" className="landing-sign-in">Sign in</Link><Link href="/app" className="landing-nav-cta">Open Boarded <Arrow /></Link></div>
        </nav>
      </header>

      <main id="main-content">
        <div className="landing-story" id="wall-story">
          <section className="landing-chapter landing-hero" aria-labelledby="hero-title">
            <p className="landing-eyebrow"><span /> A home for your climbing practice</p>
            <h1 id="hero-title">A little more<br /><span>within reach.</span></h1>
            <p className="landing-intro">A wall full of possibilities.<br />A place to make them yours.</p>
            <div className="landing-actions"><Link href="/app" className="landing-primary">Find your next line <Arrow /></Link><a href="#approach" className="landing-text-link">Explore the idea</a></div>
            <div className="landing-hero-note"><span className="landing-mini-line" /><p>Set a route. Try a move. Come back for more.</p></div>
            <a href="#approach" className="landing-scroll-link"><span className="landing-scroll-icon"><Arrow down /></span> Scroll to follow the climb</a>
          </section>

          <div className="landing-art-rail" id="wall-stage-track">
            <div className="landing-art-sticky">
              <div className="landing-art-index" aria-hidden="true"><span>FIG. 01</span><span>A PLAYGROUND FOR POSSIBILITY</span></div>
              <ClimbingWallExperience />
              <div className="landing-art-caption"><div><span className="landing-caption-label">The practice wall</span><span className="landing-caption-detail">12 × 8 ft · 14° overhang</span></div><span className="landing-material-note">A little color. A lot of potential.</span></div>
            </div>
          </div>

          <section id="approach" className="landing-chapter" aria-labelledby="approach-title">
            <p className="landing-step">01 <span>Make it your own</span></p>
            <h2 id="approach-title">Every wall.<br /><span>A blank canvas.</span></h2>
            <p className="landing-body">Big ideas start with a few holds. Bring your wall into Boarded, find a sequence, and give your next project a place to begin.</p>
            <div className="landing-feature"><span className="landing-feature-mark" aria-hidden="true">＋</span><div><h3>From wall to possibility</h3><p>Create routes on the board you know best.</p></div></div>
          </section>

          <section id="practice" className="landing-chapter" aria-labelledby="practice-title">
            <p className="landing-step">02 <span>Stay with the process</span></p>
            <h2 id="practice-title">The move.<br />The moment.<br /><span>The next try.</span></h2>
            <p className="landing-body">Keep your routes, your ideas, and the details that matter in one place. Less time trying to remember. More time finding your flow.</p>
            <div className="landing-feature"><svg viewBox="0 0 32 40" aria-hidden="true" fill="none"><path d="M7 33c0-13 18-8 18-20V5" stroke="currentColor" strokeWidth="1.5" /><circle cx="7" cy="33" r="3" fill="currentColor" /><circle cx="25" cy="5" r="3" fill="currentColor" /></svg><div><h3>Keep the line</h3><p>Document a route. Return with a fresh perspective.</p></div></div>
          </section>

          <section className="landing-chapter landing-closing" aria-labelledby="closing-title">
            <p className="landing-step">03 <span>See what comes next</span></p>
            <h2 id="closing-title">One more try.<br /><span>One new line.</span></h2>
            <p className="landing-body">For the projects you can’t leave alone.<br />And the ones you haven’t imagined yet.</p>
            <div className="landing-actions"><Link href="/app" className="landing-primary">Open Boarded <Arrow /></Link><Link href="/login" className="landing-text-link">Sign in</Link></div>
            <p className="landing-closing-note">Your wall. Your pace. Your practice.</p>
          </section>
        </div>
      </main>
      <footer className="landing-footer"><Link href="/" className="landing-wordmark">Boarded</Link><p>Made for the joy of figuring it out.</p><a href="#main-content">Back to the start <Arrow /></a></footer>
    </div>
  );
}
