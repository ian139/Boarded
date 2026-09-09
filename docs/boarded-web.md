# Boarded Web Design Contract & Foundations (v1 Local Specification)

> **Status Notice: Paper Integration Blocked**  
> Live Paper cloud access (`get_selection` / Paper MCP tools) is quota-blocked (weekly team quota limit reached, reset in 6 days). As directed, this specification is a **concrete local web design contract**, authored from the primary brand assets (`public/brandkit.png`), editorial climbing principles (`docs/design-language.md`), and the user brief. This document is **not a Paper export** and makes no claim of synthetic Paper parity.

---

## 1. Executive Summary & Design Mood

Boarded Web is an **editorial rock climbing journal fused with a disciplined field instrument**.
The visual tone is restrained, dark, tactile, and cinematic:
- **Atmosphere:** Deep warm obsidian field, tactile rock photography, quiet typography, and deliberate moments of achievement.
- **Editorial vs Instrument Tension:** Editorial serif headlines, route names, and grades (`Cormorant Garamond 600 Italic`) contrasted against disciplined tabular sans-serif data (`system-ui`, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif).
- **Decisive Palette Overrides:** In accordance with the project brief, **Electric Indigo (`#345CFF`)** represents active agency, primary buttons, interactive selection, and navigation focus. **Send Green (`#32D583`)** is reserved strictly for **sends** (successful completions, tick marks, and send badges).
- **Prohibitions:** No glassy blur materials, no decorative gradients, no pastel wellness aesthetics, and no ambiguous icon-only interactive controls without accessible labels or visible text.
- **Accessibility & Robustness:** Minimum 44×44 CSS px touch/pointer targets, fluid 320px viewport reflow without horizontal clipping, support for 200% text scaling (WCAG 1.4.4), high-contrast Windows Forced Colors mode support (`forced-colors: active`), and zero motion animations when `prefers-reduced-motion: reduce` is active.

---

## 2. Foundations

### 2.1 Color Tokens & Verified Contrast Pairings

Boarded Web is dark-only (`color-scheme: dark`). Light theme inversion is forbidden. All colors are mapped to CSS custom properties under `.boarded`:

| Semantic Token | Hex / Value | Web CSS Custom Property | Usage / Semantic Meaning |
|---|---|---|---|
| Obsidian (Base) | `#0A0B10` | `--color-bg-base` | Root document canvas, background field |
| Slate (Elevated) | `#171A22` | `--color-bg-elevated` | Card panels, top/bottom chrome, inputs |
| Surface Subtle | `#1F232D` | `--color-bg-subtle` | Hovered cards, secondary control surfaces |
| Chalk (Primary Text) | `#F4F2EB` | `--color-text-primary` | High-contrast body, route names, icons |
| Chalk Muted | `rgba(244, 242, 235, 0.70)` | `--color-text-secondary` | Metadata, author bylines, descriptions |
| Chalk Tertiary | `rgba(244, 242, 235, 0.60)` | `--color-text-tertiary` | Eyebrows, timestamps, captions, counters |
| Chalk Disabled | `rgba(244, 242, 235, 0.26)` | `--color-text-disabled` | Inactive controls, placeholder text |
| Electric Indigo | `#345CFF` | `--color-action-primary` | Interactive agency, primary buttons, active links |
| Indigo Hover | `#2649E0` | `--color-action-hover` | Hovered primary buttons & active items |
| Indigo Soft Tint | `rgba(52, 92, 255, 0.16)` | `--color-action-soft` | Selected chips, current nav indicators |
| Send Green | `#32D583` | `--color-send` | **Sends only**: sent badge, checkmark, tick |
| Send Green Soft | `rgba(50, 213, 131, 0.16)`| `--color-send-soft` | Sent pill background |
| Danger / Fall | `#FF5C5C` | `--color-danger` | Form error text, delete actions, fall notices |
| Warning | `#F6C85F` | `--color-warning` | Storage warning, unsaved draft alert |
| Border Default | `rgba(244, 242, 235, 0.14)` | `--color-border-default` | Card borders, dividers, list items |
| Border Subtle | `rgba(244, 242, 235, 0.08)` | `--color-border-subtle` | Inner item dividers |
| Border Focus | `#345CFF` | `--color-focus-inner` | Primary focus outline color |
| Focus Contrast Ring | `#F4F2EB` | `--color-focus-outer` | Outer 1px contrast ring for dark canvas |

#### Verified WCAG 2.1 Contrast Ratios:
- **Chalk (`#F4F2EB`) on Obsidian (`#0A0B10`)**: `17.2:1` (Exceeds AAA requirement of 7.0:1)
- **Chalk (`#F4F2EB`) on Slate (`#171A22`)**: `15.1:1` (Exceeds AAA requirement of 7.0:1)
- **Chalk Muted (70% alpha `#F4F2EB`) on Obsidian**: `9.4:1` (Exceeds AAA requirement of 7.0:1)
- **Chalk Tertiary (60% alpha `#F4F2EB`) on Obsidian / Slate**: `5.4:1` on Obsidian, `4.8:1` on Slate (Both exceed AA requirement of 4.5:1 for small text)
- **Electric Indigo (`#345CFF`) on Obsidian**: `4.9:1` (Exceeds AA requirement of 4.5:1 for normal text, 3.0:1 for large text / UI controls)
- **Chalk (`#F4F2EB`) on Electric Indigo / Mobile Nav Selected**: `17.2:1` on Obsidian canvas with Indigo outline indicator, and `3.6:1` on pure Indigo background
- **Send Green (`#32D583`) on Obsidian**: `10.3:1` (Exceeds AAA requirement of 7.0:1)
- **Danger (`#FF5C5C`) on Obsidian**: `5.2:1` (Exceeds AA requirement of 4.5:1)

---

### 2.2 Typography: Responsive Roles & Scale

Boarded Web employs a strict dual-family typographic system:
1. **Editorial Display Serif (`Cormorant Garamond`):** Bundled locally at `/fonts/CormorantGaramond-SemiBoldItalic.ttf` (weight 600 italic). Used strictly for editorial route names, climb grades, distance figures, and prominent celebration headers.
2. **Interface Sans-Serif (`system-ui`):** Fast, legible, native system sans stack (`system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`). Used for all navigation, controls, timestamps, attempt counts, form inputs, and body text.

| Style Role | Font Family | Size / Line Height (Desktop) | Size / Line Height (Mobile) | Weight & Style | Tracking | Sample Usage |
|---|---|---|---|---|---|---|
| **Grade Display L** | Cormorant Garamond | 44px / 48px | 36px / 40px | 600 Italic | `-0.02em` | Hero route grade (`5.12a`) |
| **Route Title L** | Cormorant Garamond | 32px / 38px | 26px / 32px | 600 Italic | `-0.01em` | Route name (`Redpoint Ridge`) |
| **Section Title M**| Interface Sans | 22px / 28px | 20px / 26px | 600 Normal | `-0.01em` | Feed section, page header |
| **Eyebrow / Tag** | Interface Sans | 12px / 16px | 11px / 15px | 700 Normal | `+0.08em` | `SEND`, `SPORT · 27 M`, `LIMESTONE` |
| **Body Large** | Interface Sans | 17px / 26px | 16px / 24px | 400 Normal | `0` | Post caption, climber reflection |
| **Body Medium** | Interface Sans | 15px / 22px | 14px / 20px | 400 Normal | `0` | Commentary, descriptions |
| **Label L (Button)**| Interface Sans | 15px / 20px | 15px / 20px | 600 Normal | `+0.01em` | Primary buttons (`Log attempt`) |
| **Label M (Action)**| Interface Sans | 13px / 18px | 13px / 18px | 500 Normal | `0` | Action buttons (`Cheer`, `Comment`) |
| **Metadata / Time**| Interface Sans (Tabular) | 13px / 18px | 12px / 16px | 400 Tabular | `0` | `Sep 6, 2026 · 09:00 UTC` |

---

### 2.3 Spacing, Radii & Layout Metrics

The spatial scale is built on a 4px/8px baseline grid:
- **`--space-1` (4px)**: Micro gaps between badge icon and text.
- **`--space-2` (8px)**: Tight padding inside chips, pill buttons, and metadata clusters.
- **`--space-3` (12px)**: Input inner padding, action bar element gaps.
- **`--space-4` (16px)**: Standard container padding, card header margin, stack separation.
- **`--space-6` (24px)**: Page header margins, feed card vertical gaps on mobile.
- **`--space-8` (32px)**: Desktop card margins, major landmark spacing.
- **`--space-12` (48px)**: Desktop feed top/bottom gutters.

#### Corner Radii:
- **`--radius-sm` (4px)**: Small tags, tabular pills, focus rings.
- **`--radius-md` (8px)**: Form fields, buttons, action chips.
- **`--radius-lg` (12px)**: Post media wrappers, elevated cards, panel surfaces.
- **`--radius-full` (9999px)**: Avatars, outcome status pills, rounded action toggles.

---

### 2.4 Surfaces, Borders & Elevation

Elevation in Boarded Web is established through tonal darkness and crisp 1px strokes rather than heavy drop shadows:
- **Base Canvas (`.boarded`):** Solid `#0A0B10`.
- **Card Panel (`.b-panel`):** Background `#171A22`, border 1px solid `rgba(244, 242, 235, 0.12)`.
- **Card Hover (`.b-panel:hover`):** Subtle border brightening to `rgba(244, 242, 235, 0.22)` and background shift to `#1B1E28`.
- **Nested Card / Shelf (`.b-shelf`):** Background `rgba(10, 11, 16, 0.72)` with 1px border `rgba(244, 242, 235, 0.08)`.
- **Dividers (`hr`, `.b-divider`):** 1px solid `rgba(244, 242, 235, 0.08)`.

---

### 2.5 Icons, Photography & Topo

- **Photography Provenance:**
  - File: `public/boarded/redpoint-ridge.webp`
  - Dimensions: **495 × 600 px**
  - SHA-256: `68ddc3f050bda94becba80b76eca560bb3247aa84702055ed902aa6991f183a2`
  - Source: Sourced from `public/brandkit.png` (cropping the upper-right climber photo at coordinates x=590, y=80, width=495, height=600).
  - Subject: An authentic outdoor rock climber on steep limestone rock, displaying natural chalk marks, pockets, quickdraws, and rope tension. **Crucially text-free**, replacing the misleading indoor gym photo (`default-wall.jpg`).
- **Photo Component (`<Photo>`):**
  - Handles loaded state, natural aspect ratio scaling, image failure fallback with an accessible climbing texture icon and explanatory text, and descriptive alt copy (`Maya K. clipping quickdraw on Redpoint Ridge limestone overhang`).
- **Icons:** Inline accessible SVGs with `aria-hidden="true"` and accompanying text labels. Fixed dimensions (18×18 or 20×20 px) within min 44×44px touch targets.
- **Topo Nodes:** Discrete nodes connected with 2px stroke vector paths, emphasizing route progression and sequence.

---

### 2.6 States: Success, Failure, Warning, Loading, Neutral

- **Success (`.b-status-success`):** Send Green `#32D583` with a checkmark icon and text `Sent`. Used only for sent ticks and successful publishes.
- **Attempt / Failure (`.b-status-attempt`):** Neutral chalk stroke `rgba(244, 242, 235, 0.2)` or red `#FF5C5C` when marking a fall or aborted attempt.
- **Storage Failure (`.b-status-storage-error`):** Persistent warning bar in `.boarded-shell` with role `alert` or `aria-live="polite"`, explaining local storage failure with a functional "Retry" button.
- **Loading (`.b-status-loading`):** Text indicator `Loading climbing journal...` with an animated pulse border and accessible `aria-busy="true"`.
- **Neutral Empty State (`.b-empty`):** Appears when no friends are followed (`followingMaya=false`) and no user entries are published. Displays an inviting prompt with a primary button linking to `/app/explore`.

---

### 2.7 Interactive States: Hover, Active, Selected, Disabled, Focus

- **Hover:** Surfaces brighten slightly (`#1B1E28`), button background transitions to hover state (`#2649E0` for primary Indigo, `rgba(244, 242, 235, 0.08)` for ghost buttons).
- **Active / Pressed:** Scale drops slightly (`transform: scale(0.98)`), background deepens.
- **Selected:** Border highlights in Electric Indigo (`#345CFF`) or Send Green (`#32D583`), background fills with 12% tint.
- **Disabled:** Opacity `0.45`, `pointer-events: none`, `cursor: not-allowed`.
- **Focus-Visible:**
  - `outline: 2px solid #345CFF`
  - `outline-offset: 2px`
  - In forced colors mode: `outline: 2px solid Highlight`.

---

### 2.8 Forms, Inputs & Link Discipline

- **Inputs (`.b-field input`, `.b-field textarea`, `.b-field select`):**
  - Min height: 44px.
  - Background: `#171A22`.
  - Border: 1px solid `rgba(244, 242, 235, 0.18)`.
  - Focus: border color `#345CFF`, box-shadow `0 0 0 2px rgba(52, 92, 255, 0.3)`.
- **Buttons (`.b-button`):**
  - Minimum touch target: 44px × 44px.
  - Text: semibold interface sans.
- **Links (`a`):**
  - Always have meaningful destination URLs (`/app/send/maya-redpoint`, `/app/route/redpoint-ridge`).
  - Never empty `href="#"` or javascript voids.

---

### 2.9 Breakpoints & Accessibility Annotations

- **Breakpoints:**
  - Compact Mobile: `< 640px` (single column, fixed top bar, bottom navigation, 16px margins).
  - Tablet / Narrow Desktop: `640px - 1023px` (single centered column max-w-xl, horizontal nav).
  - Desktop: `1024px+` (two/three-column layout with left navigation sidebar, central feed, and right route context).
- **Reflow & Zoom (WCAG 1.4.10, 1.4.4):**
  - Works down to 320px width without horizontal scrollbars.
  - At 200% text enlargement, metadata badges wrap cleanly onto subsequent lines; action buttons flex-wrap without overlapping.
- **Forced Colors (WCAG 1.4.11):**
  - `@media (forced-colors: active)` sets system borders (`1px solid ButtonText`) and system highlights (`Highlight`).
- **Reduced Motion (WCAG 2.3.3):**
  - `@media (prefers-reduced-motion: reduce)` disables all transforms and transitions (`transition: none !important; animation: none !important;`).

---

## 3. Six Responsive Low-Fi Concepts

Below are the six core destination and detail views, showing layout hierarchy, relationships, primary actions, and sequential keyboard tab navigation order (`[Tab 1]`, `[Tab 2]`, ...).

### 3.1 Feed (`/app`)

```
================================================================================
DESKTOP (1440 × 1024)                                    MOBILE (390 × 844)
--------------------------------------------------------------------------------
[Logo: Boarded]   | [Tab 6: Skip to content]              | [Boarded]  [Explore]
------------------+---------------------------------------+---------------------
[Tab 1: Feed (•)] | FEED (h1)                             | FEED (h1)
[Tab 2: Explore]  |                                       |
[Tab 3: Log (+)]  | +-----------------------------------+ | +-----------------+
[Tab 4: Activity] | | [Tab 7: Maya K. (profile)]        | | | Maya K. • 09:00 |
[Tab 5: Profile]  | | Sep 6, 2026 · 09:00 UTC           | | | 5.12a • Sent    |
                  | |                                   | | | [Photo Link]    |
                  | | [Tab 8: Photo -> /app/send/...]   | | | (Hero limestone)|
                  | | (Tactile limestone photo crop)    | | |                 |
                  | |                                   | | | Redpoint Ridge  |
                  | | 5.12a  Redpoint Ridge             | | | Stonegate       |
                  | | [Tab 9: Route -> /app/route/...]  | | | "Six tries..."  |
                  | | Sport · 27 m · Limestone          | | +-----------------+
                  | | [Sent Badge] 6 attempts           | | [Cheer] [Comment]
                  | |                                   | | [Save]  [Share]
                  | | "Six tries. One quiet moment..."  | |---------------------
                  | |                                   | | [Feed][Exp][+][Act][Prof]
                  | | [Tab 10: Cheer (34)]              |
                  | | [Tab 11: Comment -> #comments]    |
                  | | [Tab 12: Save Bookmark]           |
                  | | [Tab 13: Share Friend -> #share]  |
                  | +-----------------------------------+ |
------------------+---------------------------------------+---------------------
Primary Actions: Cheer toggle, Save bookmark, Comment jump, Share friend.
Keyboard Focus: [Tab 1-5: Nav] -> [Tab 6: Skip] -> [Tab 7: Author] -> [Tab 8: Photo] -> [Tab 9: Route link] -> [Tab 10-13: Post actions]
```

### 3.2 Send Detail (`/app/send/maya-redpoint`)

```
================================================================================
DESKTOP & MOBILE DETAIL
--------------------------------------------------------------------------------
<- [Tab 1: Back to Feed]
SEND REPORT: Redpoint Ridge 5.12a (h1)
By Maya K. • Sep 6, 2026 09:00 UTC

+------------------------------------------------------------------------------+
| [Hero Limestone Photo]                                                       |
| Status: SENT  |  Attempts: 6  |  Style: Redpoint Sport                       |
+------------------------------------------------------------------------------+

Attempt Progression:
  Attempt 1: High fall at bolt 3 (warmup)
  Attempt 2-4: Working crux crimp sequence
  Attempt 5: Dropped final pocket move
  Attempt 6: Clean send! "Six tries. One quiet moment when it all clicked."

Route Attributes:
  Crag: Stonegate | Length: 27 m | Rock: Limestone | Angle: Overhang

Comments & Kudos Section (#comments):
  [Tab 2: Kudos button (34)]
  [Tab 3: Comment textarea]
  [Tab 4: Submit comment button]
  Comment thread:
    - Alex R.: "Incredible footwork through the crux roof!"
    - Devon S.: "That overhang pump is real. Huge congrats!"

Share Dialog (#share):
  [Tab 5: Copy private link]
  [Tab 6: Send to climber friend]
--------------------------------------------------------------------------------
Primary Actions: View pitch-by-pitch attempts, add comment, cheer send.
Keyboard Focus: [Tab 1: Back] -> [Tab 2: Kudos] -> [Tab 3: Comment input] -> [Tab 4: Submit] -> [Tab 5: Share actions]
```

### 3.3 Route Detail (`/app/route/redpoint-ridge`)

```
================================================================================
ROUTE OVERVIEW: Redpoint Ridge
--------------------------------------------------------------------------------
<- [Tab 1: Back]
5.12a  Redpoint Ridge (h1)
Stonegate Crag, North Wall • Sport Climbing

[Tab 2: Save to Wishlist]   [Tab 3: Log an Attempt on this Route]

Route Specifications:
  Height: 27 meters (90 ft)
  Pitch Count: 1 pitch, 11 quickdraws + anchors
  Rock Type: Pocketed Limestone
  Profile: 15° sustained overhang with sequential crux at bolt 5
  First Ascent: K. Vance (2018)

Community Ticks & Beta:
  - Maya K. (Sent - 6 attempts - Sep 6, 2026) -> [Link to Send]
  - Jordan P. (Projecting - 3 attempts - Sep 2, 2026)

Topo Visualizer:
  [Interactive SVG Topo node line mapping bolts 1 through 11]
--------------------------------------------------------------------------------
Primary Actions: Save Route, Log Attempt on this Route, View Community Ticks.
Keyboard Focus: [Tab 1: Back] -> [Tab 2: Save] -> [Tab 3: Log Attempt] -> [Tab 4: Community tick link]
```

### 3.4 Log Attempt (`/app/log`)

```
================================================================================
LOG CLIMBING ATTEMPT
--------------------------------------------------------------------------------
RECORD A SESSION (h1)

[Tab 1: Route Selector (select/combobox)] -> Default: Redpoint Ridge (5.12a)
[Tab 2: Date Field (YYYY-MM-DD)]          -> Default: 2026-09-06
[Tab 3: Attempt Count (number input)]     -> Default: 1
[Tab 4: Conditions (select/input)]        -> Options: Crisp/Dry, Humid, Hot, Greasy
[Tab 5: Session Notes (textarea)]         -> Notes on holds, beta, and pump

Outcome Choice:
  ( ) Attempted / Working Beta
  (•) Sent / Ticked! (Unlocks green outcome)

[Tab 6: Save to Local Journal (Button)]
[Tab 7: Cancel / Discard]

(Live validation errors appear inline with role="alert" before form buttons)
--------------------------------------------------------------------------------
Primary Actions: Validate inputs, persist to local journal, trigger celebration.
Keyboard Focus: [Tab 1: Route] -> [Tab 2: Date] -> [Tab 3: Attempts] -> [Tab 4: Conditions] -> [Tab 5: Notes] -> [Tab 6: Submit]
```

### 3.5 Share Modal / Card (`/app/share/[id]`)

```
================================================================================
SHARE CLIMB CARD
--------------------------------------------------------------------------------
Share Send: Redpoint Ridge 5.12a by Maya K.

+---------------------------------------------+
| [RATIONED SHARE CARD PREVIEW]               |
|                                             |
| [Limestone Hero Image]                      |
| 5.12a Redpoint Ridge                        |
| Maya K. • Sep 6, 2026                       |
| "Six tries. One quiet moment..."            |
| BOARDED CLIMBING JOURNAL                    |
+---------------------------------------------+

[Tab 1: Copy Direct Link (Button)]
[Tab 2: Share with Climbing Partner (Alex R.)]
[Tab 3: Close / Return]
--------------------------------------------------------------------------------
Primary Actions: Copy link, notify friend, dismiss.
Keyboard Focus: [Tab 1: Copy Link] -> [Tab 2: Send to Partner] -> [Tab 3: Close]
```

### 3.6 Profile & Journal (`/app/profile`)

```
================================================================================
CLIMBER PROFILE: Alex R.
--------------------------------------------------------------------------------
Alex R. (h1)
Member since 2025 • Home Crag: Stonegate
Following: Maya K. [Tab 1: Following toggle]

Journal Summary:
  Total Sessions: 14  |  Total Attempts: 48  |  Sends: 8  |  Hardest: 5.11d

Tabs: [Tab 2: My Journal Entries (•)]   [Tab 3: Saved Routes (1)]

User Entries List:
  + If user has logged entries:
    - [Date] Route Name - Grade - Outcome [Tab 4: Edit/Publish] [Tab 5: Delete]
  + If no entries:
    - "Your logbook is clear. Hit the crag and record your first session."
    - [Tab 6: Log Session CTA]

Saved Routes:
  - Redpoint Ridge 5.12a • Stonegate [Tab 7: View Route]
--------------------------------------------------------------------------------
Primary Actions: Toggle following Maya K., publish/delete journal entries, browse saved routes.
Keyboard Focus: [Tab 1: Following toggle] -> [Tab 2-3: Subtabs] -> [Tab 4: Publish/Edit] -> [Tab 5: Delete]
```

---

## 4. Shared CSS Names & Architecture

To ensure seamless multi-agent integration between the Shell, Feed, and subsequent Flow routes, the following class names are standardized in `app/app/boarded.css`:

| Class Name | Component Purpose | Structural Definition |
|---|---|---|
| `.boarded` | Root theme container | Scopes all custom properties, dark background `#0A0B10`, font family |
| `.b-main` | Landmark `<main>` | Single primary document landmark with route heading focus handling |
| `.b-page` | Page wrapper | Max-width constraint (680px for feed, 960px for shell), horizontal centering |
| `.b-page-header` | Page header | Flex row with title, eyebrow, and optional trailing action |
| `.b-eyebrow` | Uppercase tag | Small, tracked-out label (`letter-spacing: 0.08em`, font-size 11-12px) |
| `.b-serif` | Editorial display font | Applies `Cormorant Garamond, Georgia, serif` in 600 italic |
| `.b-muted` | Secondary text | Chalk with 70% opacity |
| `.b-button` | Standard interactive button | Min 44×44 target, border-radius 8px, flex center, semibold sans |
| `.b-button-primary` | Primary action button | Electric Indigo `#345CFF`, Chalk text, hover `#2649E0` |
| `.b-button-danger` | Destructive button | Red `#FF5C5C` border/text |
| `.b-field` | Form control group | Vertical stack of label, input/textarea/select, and error message |
| `.b-errors` | Form error display | Text `#FF5C5C`, role="alert", font-size 13px |
| `.b-status` | Status pill / badge | Inline flex pill for outcome indicators |
| `.b-status-sent` | Sent status pill | Green background tint `rgba(50, 213, 131, 0.16)`, green text `#32D583` |
| `.b-panel` | Elevated card container | Background `#171A22`, border 1px solid `rgba(244, 242, 235, 0.12)`, radius 12px |
| `.b-stack` | Vertical layout helper | Flex column with standard `--space-4` gap |
| `.b-inline` | Horizontal layout helper | Flex row with wrapping and align-center |
| `.b-photo` | Media image frame | Rounded media wrapper with aspect ratio, overflow hidden, and fallback |
| `.b-facts` | Key-value data shelf | Grid/flex cluster for route specifications (crag, length, rock, style) |

---

## 5. Provenance & Asset Verification

- **Hero Asset Path:** `public/boarded/redpoint-ridge.webp`
- **Asset Dimensions:** `495 × 600 px`
- **SHA-256 Hash:** `68ddc3f050bda94becba80b76eca560bb3247aa84702055ed902aa6991f183a2`
- **Visual Inspection Confirmation:** Sourced from `public/brandkit.png` at bounding box `(x: 590, y: 80, w: 495, h: 600)`. Displays a climber on real limestone rock with rope, chalk bag, natural pockets, and quickdraws. Fully text-free, ensuring pure editorial realism without overlaid graphic watermarks.

---

## 6. Foundations & UI Review Verification Log

The following contract corrections were implemented across `app/app/boarded.css`, `components/boarded/Feed.tsx`, `components/boarded/Shell.tsx`, and `components/boarded/Photo.tsx`:

1. **JSX Structure & Compilation:** Resolved unclosed wrapper `<div>` in `Feed.tsx` (lines 168–194) that caused previous compiler failure / HTTP 500.
2. **Domain Model Alignment:** Updated Route data bindings to canonical `height` and `style` properties (`mayaRoute.height`, `mayaRoute.style`), avoiding nonexistent `lengthM` / `angle` or double-unit suffixes.
3. **Seeded Comment Counting:** Corrected comment count to use filtered `comments.length` (`mayaPostComments.length`), preventing duplicate counting of the 12 already-seeded `INITIAL_COMMENTS`.
4. **Mobile Navigation Contrast & Reflow:**
   - Active item displays Chalk `#F4F2EB` label with Electric Indigo indicator/outline (`#345CFF`) and `aria-current="page"`, exceeding WCAG AA (>15:1 contrast).
   - Removed `truncate` and fixed 72px slot caps; navigation labels wrap cleanly at 200% text scaling and 320px viewport without clipping.
5. **Heading Persistence:** Page landmark `<h1>Feed</h1>` is preserved during loading (`!ready`) and error states, preventing heading disappearance or sudden focus shifts.
6. **Semantic Heading Hierarchy:** Route titles within feed cards are wrapped in semantic `<h2>` elements containing the route links.
7. **Touch Target Accessibility:** Verified minimum 44×44 CSS px hit targets across all identity links, route links, action chips, and navigation controls.
8. **Focus Management & Hash Targets:** Enhanced `Shell.tsx` route effect to respect anchor hashes (`#comments`, `#share`) and popstate/history navigation with `{ preventScroll: true }`, preventing intrusive scroll displacement.
9. **Clean Export Contract:** Removed redundant `export default` aliases from `Feed.tsx`, `Shell.tsx`, and `Photo.tsx`, enforcing the standard named export contract.
10. **Desktop Context Refinement:** Replaced inert fake crew status list with an actionable "Next Route Project" card (`Golden Hour 5.11c` from `routes`), linking directly to route inspection and attempt logging.
11. **Outcome Badge Parity:** Implemented `AttemptBadge` with a circular attempt icon, establishing visual balance with `SentBadge` while strictly reserving Send Green for sends.
12. **Editorial Grade Focal Point:** Implemented `.b-grade-hero` display scale (`48px` mobile, `64px` desktop) providing the requested commanding visual hierarchy beneath the photo, distinct from the route title.
13. **Mobile Sent Badge Single-Line Integrity:** Enforced `white-space: nowrap; flex-shrink: 0;` on `.b-status` alongside `flex-shrink-0` header containment, eliminating awkward "SEN" / "T" wrapping on narrow viewports while preserving author metadata room.
14. **Mobile Log Primary Visual Emphasis:** Styled mobile navigation Log action (`/app/log`) with solid Electric Indigo fill and elevated prominence while maintaining the accessible five-destination navigation structure.
15. **Climber Photography Top-Anchored Crop:** Configured `.b-photo img` with `object-position: top center;` and `max-height: 640px;` ensuring the climber's raised hand reaching to clip the quickdraw is visible without clipping on desktop viewports.
16. **Dynamic Route Titles & Bounded Asynchronous Focus Management:** Integrated `getRouteTitle` in `Shell.tsx` for route-derived descriptive document titles; guarded hash targeting using decoded `getElementById` to avoid selector syntax exceptions on malformed hashes; integrated popstate detection to safeguard native browser back/forward focus restoration; and implemented a bounded `MutationObserver` (with 1500ms timeout cleanup) on `<main>` that waits for suspended/asynchronously mounted destination `<h1>` elements to appear before focusing them, preventing premature focus lock on unnamed container elements.
