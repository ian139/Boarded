## Context

Create a public marketing landing page at `/` in the Aura.build aesthetic: restrained editorial composition, generous negative space, precise typography, and one immersive physical focal object. The current route-studio home moves intact to `/app`; the landing page shares Boarded’s Obsidian/Chalk/Send Green identity but contains no dashboard, product-feature grid, metrics, screenshots, or explanatory app-functionality copy. The approved climbing-wall relief becomes a passive right-side WebGL element that turns and relights slightly as the document scrolls, with no drag, zoom, hover tracking, or other direct manipulation.

## Approach

### 1. Record the marketing-surface contract before implementation

- Extend `docs/design-language.md` under `# 10. Screen patterns` with a `## Marketing landing` subsection. Define `/` as a public editorial surface distinct from the web studio at `/app`; preserve the existing semantic palette, 4/8 spacing rhythm, 600/900/1200 breakpoints, opaque web surfaces, Cormorant/sans hierarchy, 44px targets, and no-glow/no-glass rules.
- Fix the section order and interaction contract: normal-flow header, hero, manifesto, ordered principles strip, closing CTA, footer; one passive 3D wall; no text over the wall; no feature cards; no parallax or idle loop; reduced motion uses a static image.
- Use Aura.build’s minimal editorial structure, not Miro Aura or a generic luminous “aura” treatment.

### 2. Create a page-specific low-poly asset packet independently of route work

- Read the canonical source from `~/Desktop/climbing-wall-photo-3d.blend` (fallback source: the byte-identical `public/walls/generated/photo-wall-relief.blend` if present). Do not overwrite, delete, or stage any unrelated files already under the untracked `public/walls/generated/` tree.
- Export a new runtime asset at `public/walls/generated/photo-wall-relief-web.glb`. Preserve the front silhouette, shallow relief, watertight shell, UVs, outward winding, and one textured PBR material; remove all cameras/lights from the GLB.
- Target at most 20,000 vertices, 40,000 rendered triangles, and 1.5 MB. First apply a measured collapse decimation near the current 70,646-triangle mesh while protecting perimeter/major hold edges and confirming manifold topology. If decimation breaks the shell or exceeds the budget, rebuild a stitched `176×105` relief grid by sampling the existing displacement, then join it to the 0.13 m back/side slab; this fallback is the required implementation, not a new decision point.
- Replace the embedded 1136×680 PNG with the rectified 568×340 source encoded as embedded JPEG at quality 88; keep the model uncompressed so `GLTFLoader` needs no Draco/Meshopt decoder. Preserve recognizable hold boundaries in front and three-quarter comparison renders.
- Create `public/walls/generated/photo-wall-relief-web-fallback.webp` from the approved front render, 960px wide, WebP quality 82, retaining the full wall and Obsidian surround; target 180 KB or less. This is the loading, reduced-motion, and WebGL-failure image.

### 3. Cut the functional application over from `/` to `/app` without aliases

- Move the complete current `app/page.tsx` implementation to the new `app/app/page.tsx`; do not duplicate it or leave a re-export/redirect shim. Change its two desktop/mobile Home links from `/` to `/app`; all wall/route store behavior, dialogs, and `/editor` navigation remain unchanged.
- Replace `app/page.tsx` later with the server-rendered marketing page. Until that replacement lands, keep `/app` building and rendering the old functional home so the route tree stays usable.
- Migrate app-intent root destinations to `/app`:
  - `app/editor/page.tsx`: permission-denied, route-not-found, fetch-error, save-success pushes, and the header back link.
  - `app/profile/page.tsx`: header back link and “Browse Routes.”
  - `app/settings/page.tsx`: header back link only.
  - `app/login/page.tsx`: already-authenticated and successful-login redirects.
  - `app/signup/page.tsx`: already-authenticated and successful-signup-without-confirmation redirects.
  - `components/shared/BottomNav.tsx`: Home item and active state.
- Keep public/unauthenticated exits on the marketing root: login/signup header back links remain `/`; settings logout redirects to `/`; `app/share/[token]/page.tsx` back link remains `/`.
- In `components/shared/BottomNav.tsx`, return `null` only when `pathname === '/'`, so no app chrome overlays the marketing page; `/app` and existing functional routes retain the mobile app navigation.
- Change `public/manifest.json` `start_url` from `/` to `/app`. In `public/sw.js`, add `/app` to `SHELL_ROUTES`; retain `/` for the marketing document. On failed app-intent navigations (`/app`, `/editor`, `/profile`, `/settings`), fall back to cached `/app`; public/auth/share failures fall back to cached `/`.

### 4. Add the minimal direct-Three runtime

- Add exact runtime dependency `three@0.185.1` and exact dev dependency `@types/three@0.185.4`; update `package.json` and `package-lock.json` through npm, not by hand. Seed the isolated dependency packet with the current primary-checkout lockfile so the user’s existing lockfile changes are preserved; integrate only the Three-related lockfile delta.
- Do not add React Three Fiber, Drei, `model-viewer`, OrbitControls, DracoLoader, or Meshopt. One passive mesh does not justify those abstractions/decoders.
- Create `components/landing/PhotoWallHero.tsx` as a `'use client'` component with no public props; it is a single-purpose landing visual with fixed URLs `/walls/generated/photo-wall-relief-web.glb` and `/walls/generated/photo-wall-relief-web-fallback.webp`.
- Server-render the stable fallback image and wrapper first. Inside `useEffect`, dynamically import `three` and `three/addons/loaders/GLTFLoader.js`; no WebGL/browser object may be touched at module evaluation time.
- Build one `Scene`, transparent `WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' })`, `PerspectiveCamera`, `HemisphereLight`, and neutral Chalk `DirectionalLight`. Set sRGB output, AgX tone mapping at exposure 1, no shadows, and pixel ratio capped at 1.5. Load the GLB, center it with `Box3`, face its shallow Z axis toward a positive-Z camera, and fit the full bounds with a 12% margin rather than hard-coded device coordinates.
- Keep the wall under a pivot group. Compute local section progress as `clamp((innerHeight - rect.top) / (innerHeight + rect.height), 0, 1)`. Map progress to yaw `-0.06 → +0.06 rad`, pitch `+0.02 → -0.02 rad`, directional-light X `-3 → +3`, and directional intensity `2.4 → 2.8`; keep the hemisphere fill at `0.65`. On scroll, ease current values toward targets with a damped requestAnimationFrame and stop rendering once every delta is below `0.0005`; render on first load and resize, with no idle animation loop.
- Never install or attach controls. Canvas uses `pointer-events: none`, `aria-hidden="true"`, no tab stop, and no pointer/wheel listeners. Wrap the visual with `role="img"` and `aria-label="A relief model of a climbing wall covered in colorful holds."`; give the underlying fallback image empty alt text to avoid duplicate announcements.
- Keep the fallback visible until the first successful WebGL frame, then crossfade it over 180 ms. If reduced motion is active, WebGL/context creation fails, GLB/texture loading rejects, or `webglcontextlost` fires, retain/restore the fallback and leave the page usable without an uncaught error.
- Use `ResizeObserver` to resize renderer/camera without layout shifts. On cleanup: guard late async resolution, cancel RAF, remove scroll/context listeners, disconnect the observer, traverse and dispose geometries/materials/textures and ImageBitmaps, remove light targets/models, then call `renderer.dispose()`.

### 5. Build the Aura.build-inspired public page with fixed brand copy

- Replace `app/page.tsx` with a server component exporting landing metadata (`title: 'Boarded — Keep the line.'`, `description: 'A quiet climbing journal built around movement, effort, and return.'`). Keep root layout metadata generic enough for app routes; do not expose app-studio functionality in landing metadata.
- Add the exact self-hosted `@font-face` for `/fonts/CormorantGaramond-SemiBoldItalic.ttf` in `app/globals.css`. Scope its use to landing wordmark/headlines via landing classes; do not globally restyle existing app screens or remove the current root font configuration in this packet.
- Render this semantic structure and exact copy:
  1. Skip link to `#main-content`.
  2. Normal-flow `header > nav`: `Boarded`; desktop anchors `Approach` → `#approach` and `Practice` → `#practice`; `Sign in` → `/login`; primary `Open Boarded` → `/app`. Below 600px show only wordmark and `Open Boarded`.
  3. Hero `section[aria-labelledby='hero-title']`: eyebrow `A climbing journal`; `h1` `Keep the line.`; body `A quiet place for the movement, effort, and return that make climbing yours.`; primary `Enter Boarded` → `/app`; secondary `Our approach` → `#approach`; `PhotoWallHero` in a sibling right-side figure/stage, never behind text.
  4. Manifesto `#approach`: eyebrow `The practice`; `h2` `The wall changes. Your line stays.`; body `Climbing is repetition, attention, and the courage to try again. Boarded is built in that spirit.`
  5. Ordered principles list `#practice`: `Notice the move — Presence before progress.`; `Trust the process — One attempt at a time.`; `Return with intent — The next line starts here.` No icons, metrics, or cards.
  6. Closing CTA: `h2` `For the climb ahead.`; body `Stay close to the wall. Keep moving.`; `Open Boarded` → `/app`; `Sign in` → `/login`.
  7. Footer: `Boarded`, `A climbing journal.`, and `Sign in` → `/login`.
- Add only scoped landing classes in `app/globals.css`. Use existing semantic variables—Obsidian field, Chalk text, one Send Green primary action, Slate/Surface Card closing region, subtle Chalk dividers. The visual stage may use an opaque Slate-to-Obsidian neutral gradient; no colored glow, blur, glass, gradient text, or heavy shadow.
- At `>=900px`, use the documented 12-column grid with copy spanning 5 columns, visual 7 columns, 48px gap, and 64px block padding; cap body copy at 42ch. At `600–899px`, stack copy then visual with 24px side margins and 48px rhythm. Below 600px use 20px margins, 48/48 headline, actions that wrap/stack without truncation, a 4:3 contained visual stage, and a one-column principles list. At wide desktop cap the container at 1200px; at 200% zoom reflow rather than clip or horizontally scroll.
- Use 52px, 12px-radius CTA targets and the existing focus ring. Gate hover styling behind `(hover: hover) and (pointer: fine)`. Keep one `h1`, sequential `h2`s, native links, an ordered list, `main`, and `footer`; the brand copy remains complete without the 3D visual.

## Critical files & anchors

- `app/page.tsx` — current `Home` client component must move intact before this path becomes the server-rendered marketing page.
- `components/landing/PhotoWallHero.tsx` — new direct-Three client island; owns loading, passive scroll response, fallback, failure behavior, and GPU cleanup.
- `components/shared/BottomNav.tsx` — `navItems[0]` and pathname guard separate public `/` from functional `/app` on mobile.
- `app/globals.css` — existing semantic tokens/reduced-motion rules; add scoped landing layout, local display face, stage stacking, and fine-pointer hover rules without changing app-wide palette.
- `public/walls/generated/photo-wall-relief-web.glb` — new web-only low-poly derivative; source assets and unrelated generated files remain untouched.

## Verification

- From repository root with the existing environment, run `npm exec tsc -- --noEmit`, `npm run lint`, `npm test`, and `npm run build`. All exit 0; the production route table contains both `/` and `/app`, and build output has no server-side `window`, WebGL, Three, or client-boundary error.
- Run an asset inspection before browser work: GLB is ≤1.5 MB, ≤20,000 vertices, ≤40,000 triangles, one watertight outward-wound mesh/material, embedded JPEG, finite positions/normals/UVs, and zero camera/light nodes; fallback WebP is ≤180 KB. Import the GLB with Blender 5.2.1 or trimesh and compare front/angle renders to the canonical source so major holds, slab silhouette, and shallow relief remain recognizable.
- Start the actual app with `npm run dev`. Browser-drive `/` at 1440×1000, 1024×768, 768×1024, and 390×844; capture rendered screenshots. Expected: Aura.build-style editorial hierarchy, no app BottomNav, no dashboard/functionality explanation, right-side 3D on desktop, copy-before-visual stack below 900px, no clipping/horizontal overflow, and complete CTA labels.
- On `/`, observe network/console: fallback paints before JavaScript/GLB completion; `/walls/generated/photo-wall-relief-web.glb` returns 200; exactly one canvas replaces the fallback after the first frame; no console errors. Scroll from hero start through manifesto and back: wall only yaws/pitches within the specified bounds, direct light crosses laterally, no idle spin continues after settling, and drag/wheel/pointer input never controls the model.
- Emulate `prefers-reduced-motion: reduce`: expected no WebGL context/canvas and the static WebP remains visible. In a separate run, abort the GLB request and then simulate `webglcontextlost`: expected fallback remains/restores, copy and links still work, and no uncaught rejection appears.
- Resize and rotate the mobile viewport, then navigate away/back at least three times. Expected: one canvas only, correct camera fit, pixel ratio capped at 1.5, no accumulating scroll listeners/RAF, and no visible layout shift.
- Keyboard/screen-reader check: skip link reaches `#main-content`; focus order is header → hero actions → manifesto/principles → closing → footer; every CTA is at least 44×44px with visible green ring and Obsidian offset; the canvas is skipped and the visual label is announced once.
- Route regression: `/app` renders the previous route studio unchanged; mobile BottomNav Home points to and activates on `/app`; editor/profile/settings app-back actions return to `/app`; successful login/signup returns to `/app`; login/signup back links, logout, and public-share back links return to `/`. Verify `manifest.json` launches `/app` and offline cache includes both `/` and `/app`, with app-intent failures using `/app` fallback.

## Assumptions & contingencies

- “Aura” means the Aura.build landing-page aesthetic, selected by the user: editorial minimalism and generous negative space adapted to Boarded’s existing dark semantic palette.
- `/` becomes the public brand landing page and the current functional home moves to `/app`; this is a clean cutover with no compatibility alias at `/`.
- The 3D wall is meaningful atmosphere, not product instruction. If WebGL or motion is unavailable, the static wall image is the complete intended fallback rather than an error state.
- Existing uncommitted `package-lock.json` and `public/walls/generated/` contents are user work. Implementation must preserve them byte-for-byte except for the explicit Three dependency entries and the two new `photo-wall-relief-web` assets; unrelated generated files are never cleaned, staged, or replaced.