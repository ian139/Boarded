# Boarded Green — iOS and Web Design Language

## 1. Design thesis

Boarded should feel like an **editorial climbing journal fused with a precise field instrument**.

The interface is not a generic fitness tracker, outdoor marketplace, or social feed. It combines:

- The elegance of a high-end climbing publication.
- The immediacy of a tool used beside the wall.
- The precision of route, attempt, and performance data.
- The physical texture of rock, rope, chalk, metal, and skin.
- The satisfaction of progress without turning climbing into shallow gamification.

The central visual tension is:

> **Expressive serif moments for identity and achievement; disciplined sans-serif systems for action and information.**

Boarded lives on a warm-black field on iOS and web. Chalk-colored typography provides clarity. Vivid green identifies agency, progression, selection, and successful outcomes. Photography supplies the physical reality.

---

# 2. Brand principles

Every screen should satisfy these principles.

## Editorial first glance, technical second glance

A screen should normally have one immediate emotional focal point:

- A route grade.
- A vertical-gain total.
- A photograph.
- A session result.
- A short editorial headline.

The second layer contains precise details:

- Attempt count.
- Time.
- Route attributes.
- Success rate.
- Topo nodes.
- Venue and date.
- Social metadata.

Do not give every fact equal visual weight.

## Progress has a line

The continuous Boarded mark suggests movement from gym to crag. Extend that language throughout the app:

- Route traces.
- Topo paths.
- Attempt timelines.
- Grade progression.
- Session history.
- Upload and sync progress.
- Onboarding steps.

Prefer directional lines and meaningful nodes over generic charts, decorative waves, or dashboard rings.

## Green means agency

Send Green should indicate:

- The primary action.
- Current selection.
- Active route or topo node.
- Positive progression.
- A successful send.
- A personal record.
- A focused input.
- A completed workflow step.

Green must not decorate every card, number, or icon. If everything is green, nothing feels active or earned.

## Rock remains physical

Photography should show climbing as a tactile activity:

- Hands on holds.
- Shoes on textured footholds.
- Rope fibers.
- Quickdraws and carabiners.
- Chalk and skin.
- Body tension.
- Rock grain.
- Gym wall geometry.

Avoid distant summit imagery, generic hiking scenes, staged lifestyle smiles, and oversaturated outdoor stock photography.

## Quiet frame, vivid achievement

The interface remains dark, controlled, and restrained. Sends, records, and meaningful progress become the luminous moments.

Celebration comes from hierarchy, motion, and precision—not confetti, neon gradients, badges, or artificial game mechanics.

---

# 3. Color system

## Core palette

| Token | Value | Purpose |
|---|---:|---|
| Obsidian | `#0A0B10` | Primary background and application field |
| Slate | `#171A22` | Elevated surfaces, fields, grouped regions |
| Chalk | `#F4F2EB` | Primary text, important icons, route lines |
| Send Green | `#32D583` | Primary action, selection, progress, success |

The palette is intentionally warm. Do not replace Obsidian with pure `#000000` or Chalk with pure white. Those substitutions make the app colder and more generic.

### Verified contrast

- Send Green on Obsidian: approximately `10.28:1`.
- Chalk on Obsidian: approximately `17.55:1`.
- Send Green on Slate: approximately `9.1:1`.
- Chalk on Slate: approximately `15.53:1`.

These pairings are safe foundations. Opacity-derived secondary colors must still be tested at their actual sizes and weights.

## Shared semantic tokens

The token names and meanings are the cross-platform contract. iOS color assets or Swift constants and web CSS custom properties MUST map to the same semantic token; components MUST consume semantic names rather than palette values.

| Semantic token | Value | Web custom property |
|---|---:|---|
| `background/base` | `#0A0B10` | `--color-background-base` |
| `background/elevated` | `#171A22` | `--color-background-elevated` |
| `surface/card` | `#0D0F14` | `--color-surface-card` |
| `surface/selected` | `rgba(50, 213, 131, 0.12)` | `--color-surface-selected` |
| `text/primary` | `#F4F2EB` | `--color-text-primary` |
| `text/secondary` | `rgba(244, 242, 235, 0.64)` | `--color-text-secondary` |
| `text/tertiary` | `rgba(244, 242, 235, 0.44)` | `--color-text-tertiary` |
| `text/disabled` | `rgba(244, 242, 235, 0.30)` | `--color-text-disabled` |
| `stroke/default` | `rgba(244, 242, 235, 0.18)` | `--color-stroke-default` |
| `stroke/subtle` | `rgba(244, 242, 235, 0.10)` | `--color-stroke-subtle` |
| `divider` | `rgba(244, 242, 235, 0.08)` | `--color-divider` |
| `accent/default` | `#32D583` | `--color-accent-default` |
| `accent/pressed` | `#27B873` | `--color-accent-pressed` |
| `accent/soft` | `rgba(50, 213, 131, 0.14)` | `--color-accent-soft` |
| `accent/onAccent` | `#0A0B10` | `--color-accent-on-accent` |
| `danger` | `#FF6B64` | `--color-danger` |
| `warning` | `#F6C85F` | `--color-warning` |
| `information` | `#69A7FF` | `--color-information` |


## iOS material and photo-overlay tokens

These tokens are **iOS-only**. They do not change the web surface contract. In SwiftUI, apply the named system `Material` first, then composite the specified Obsidian tint as a separate layer above it; do not approximate either layer with a translucent solid.

| Token | Exact iOS construction | Use |
|---|---|---|
| `material/photoHUD` | `.ultraThinMaterial`, then Obsidian at 58% | Compact photo HUD controls and single-line pills only |
| `material/sessionFactShelf` | `.thinMaterial`, then Obsidian at 64% | Multi-fact session shelves attached to photography |
| `material/floatingRail` | `.thinMaterial`, then Obsidian at 64% | Logger/media rails floating over underlapping content |
| `material/contentChrome` | `.regularMaterial`, then Obsidian at 72% | Navigation or tab chrome only when content visibly underlaps it |
| `material/rim` | 1 pt top/leading Chalk at 18%, plus 1 pt bottom/trailing Chalk at 8% | Directional edge separation for standard contrast |
| `material/rimHighContrast` | 1 pt top/leading Chalk at 32%, plus 1 pt bottom/trailing Chalk at 14% | Increase Contrast replacement for `material/rim` |
| `overlay/scrimTop` | Obsidian 0% → 58% | Top-aligned identity or navigation text over a photo |
| `overlay/scrimBottom` | Obsidian 0% → 82% | Bottom-aligned session facts and actions over a photo |
| `overlay/scrimExport` | Obsidian 0% → 88%, rasterized | Deterministic exported-share text backing |

The tint percentage is the alpha of the semantic Obsidian layer composited **above** the system material; it is not the final measured opacity or color of the blended result. Apply `material/rim` after the tint: the Chalk highlight follows the top and leading edges, while the lower-alpha Chalk stroke follows the bottom and trailing edges. Material category, tint, and rim are fixed by component and do not vary to imitate individual photographs.

Photo compositions use three explicit depth layers derived from the tonal structure of `docs/assets/boarded-hero.webp`: (1) full-bleed documentary photography as the physical field, (2) localized Obsidian scrims only behind text and controls, and (3) a restrained frosted control/fact layer with the specified directional rim. Preserve brighter wall/rock planes as the focal middle tone and let surrounding Obsidian frame them. Do not add colored ambient glow, global image blur, glossy specular highlights, or multiple luminous borders.
## Semantic color rules

- Green is not a substitute for Chalk body text.
- A sent attempt uses green plus a checkmark and the word “Sent.”
- A failed attempt uses red plus a cross and an explicit outcome.
- A selected route uses green line/node treatment plus a selected state.
- Destructive system actions never use green.
- A climbing fall is an activity outcome—not an app error.
- System failures and climbing outcomes must have separate visual semantics.

## Appearance strategy

Boarded is dark-only on iOS and web. There is no light theme, automatic inversion, or conditional light-mode adaptation.

- iOS MUST render the dark palette regardless of the system appearance and declare dark appearance for Boarded-owned surfaces.
- Web MUST set `color-scheme: dark` and keep the same semantic-token mapping when `prefers-color-scheme: light` matches.
- Browser and native system-owned controls MUST request their dark treatment.
- Light-preference detection MUST NOT substitute colors or expose a theme toggle.
- Photography, embedded third-party content, and system permission UI are not recolored, but their Boarded-owned surroundings remain dark.

---

# 4. Typography

## Dual-family structure

Boarded requires two distinct typographic voices.

### Display serif

Use **Cormorant Garamond Semibold Italic (weight 600, italic)** under the **SIL Open Font License 1.1 (OFL-1.1)** for:

- The Boarded wordmark.
- Route grades.
- Distances.
- Major achievements.
- Editorial headlines.
- Session-result focal metrics.
- Personal records.

This is the sole Boarded display serif; do not substitute New York, Canela, Editorial New, or a “comparable” family. Both platforms expose weight 600 italic only. The fallback chain is `Georgia, "Times New Roman", serif`; fallback is a loading or font-failure behavior, not an alternate approved brand face.

#### Deterministic font artifact contract

The one canonical artifact is the unmodified static TTF from upstream commit `6d210fd3550b7358ca62d6ba3e354ec1ec940813`: `fonts/ttf/CormorantGaramond-SemiBoldItalic.ttf`, Git blob `d68f5b4360bcebcc1d331ba63522c79f3988c0e1`, SHA-256 `6a9d9b79e12d1bacf936714597f04053de53c3728fefa926629856e82c69e129`. iOS and web MUST ship that file byte-for-byte with the identical filename `CormorantGaramond-SemiBoldItalic.ttf`. Do not generate, subset, convert, rename, or otherwise modify the font.

- **iOS:** bundle `CormorantGaramond-SemiBoldItalic.ttf`, register that exact filename in `UIAppFonts`, and address the face by its PostScript name `CormorantGaramond-SemiBoldItalic`.
- **Web:** self-host the identical TTF at `/fonts/CormorantGaramond-SemiBoldItalic.ttf`; do not load it from a third-party font CDN. Its declaration is exactly:

```css
@font-face {
  font-family: "Cormorant Garamond";
  src: url("/fonts/CormorantGaramond-SemiBoldItalic.ttf") format("truetype");
  font-weight: 600;
  font-style: italic;
  font-display: swap;
}
```

Ship the exact upstream `OFL.txt` from commit `6d210fd3550b7358ca62d6ba3e354ec1ec940813` as `licenses/Cormorant-Garamond-OFL.txt`; iOS must bundle it with the application, and web distribution must include it with the self-hosted artifact. That pinned license declares no Reserved Font Names. Because this contract permits no derived or subset font, no Reserved Font Name renaming applies.

Do not use the serif for:

- Paragraphs.
- Buttons.
- Input labels.
- Timestamps.
- Navigation tabs.
- Dense numerical tables.
- Attempt rows.

### Interface sans

- iOS uses native SF Pro through system text styles; never bundle or self-host SF Pro.
- Web uses `system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`.
- Interface weights are regular 400, medium 500, and semibold 600.

Use the interface sans for:

- Navigation.
- Labels.
- Body copy.
- Buttons.
- Form controls.
- Times.
- Metadata.
- Social actions.
- Settings.
- Tabular data.

## Recommended type scale

| Style | Size / line height | Use |
|---|---:|---|
| Display XL | 64/64 | Rare onboarding or campaign statement |
| Display L | 48/48 | Route grade, milestone, session result |
| Display M | 40/42 | Major metric or detail-header grade |
| Display S | 32/36 | Compact card grade |
| Title L | 28/34, semibold | Screen title |
| Title M | 22/28, semibold | Section or sheet title |
| Body L | 17/24 | Main readable content |
| Body M | 15/21 | Supporting content |
| Label L | 15/20, medium | Buttons and important labels |
| Label M | 13/18, medium | Compact UI labels |
| Caption | 12/16 | Metadata |
| Data L | 34/38, tabular | Large changing metric |
| Data M | 22/28, tabular | Tile metric |
| Data S | 15/20, tabular | Times and attempt rows |

## Typographic behavior

- Grades such as `5.12a` must remain visually intact.
- Do not fake the suffix as a superscript unless the grading system requires it.
- Use tabular numerals for timers, attempts, timestamps, chart values, and changing counters.
- Use uppercase, widely tracked labels sparingly for editorial eyebrows:
  - `TODAY`
  - `SESSION COMPLETE`
  - `NEW PERSONAL RECORD`
- Green labels should usually be short. Paragraphs remain Chalk.

## Dynamic Type

All iOS sans text uses the matching system text style with `adjustsFontForContentSizeCategory`; Boarded’s display face scales through `UIFontMetrics` from the documented base size. There are no fixed-height text containers and no minimum-scale-factor escape hatch.

- Through the standard categories, the structured photo overlay may keep venue on one line only when it fits without shrinking; facts may use two columns.
- At the first Accessibility category and above, venue and featured route wrap, fact shelves become one fact per row, controls move below the photo when necessary, and captions have no line limit.
- At Accessibility Large and above, no essential text may remain over a visually busy photo. Move the factual block to an opaque `surface/card` continuation immediately below the image while preserving image-first reading order.
- Route grades never truncate or split internally. Attempt timestamps move below their labels. Serif headlines may wrap to three lines; body content has no fixed line limit.
- Glass containers grow with content until the preceding thresholds trigger the opaque continuation; they never clip, scroll internally, or conceal facts.
- VoiceOver order is author/time, photo description, venue and session facts, caption, then reactions/actions, regardless of visual overlap.
---

# 5. Spacing and layout

## Spatial system

Use a 4-point base and 8-point primary rhythm.

```text
4, 8, 12, 16, 20, 24, 32, 40, 48, 64
```

## iPhone layout

- Horizontal screen margin: `20 pt`.
- Pro Max or wider regular layouts: `24 pt`.
- Standard card padding: `16 pt`.
- Feature-card padding: `20 pt`.
- Dense tracker row: `12 pt` vertical, `16 pt` horizontal.
- Card gap: `12 pt`.
- Vertical content gap: `16 pt`.
- Section gap: `32 pt`.
- Eyebrow to title: `8 pt`.
- Title to content: `16 pt`.

Use a four-column compact grid with 12-point gutters. Most components should span two or four columns.

Avoid three-column metric layouts on narrow iPhones. Two columns are clearer and more usable.

## Web token mapping and responsive layout

On web, every numeric spacing, radius, stroke, type-size, and target token maps `1 pt` to `1 CSS px` at the authored layout level. Browser zoom and device pixel ratio provide physical scaling; do not convert tokens using DPR. The shared spacing sequence is therefore `4, 8, 12, 16, 20, 24, 32, 40, 48, 64px`, and radius names retain the same numeric values in CSS px.

Use content-driven reflow at these fixed viewport breakpoints:

| Range | Layout | Container |
|---|---|---|
| `< 600px` | Mobile, four columns, 12px gutters | Fluid, 20px side margins |
| `600–899px` | Compact tablet, eight columns, 16px gutters | Fluid, 24px side margins |
| `900–1199px` | Desktop, twelve columns, 20px gutters | `min(100% - 48px, 1120px)` |
| `≥ 1200px` | Wide desktop, twelve columns, 24px gutters | Maximum 1200px |

- Text content uses a maximum readable measure of `68ch`; dense data regions may use the full container.
- A component reflows when its own available width is insufficient; it MUST NOT shrink type, clip actions, or introduce horizontal page scrolling to preserve a desktop composition.
- Below 600px, side-by-side primary regions stack in reading order, metric triples become rows or a two-column group, action groups wrap with the primary action first, and tables become labeled rows or gain an explicitly labeled local scroll region.
- Media preserves its defined aspect ratio and crops intentionally. Route grades, outcome labels, and primary actions never truncate.
- At 200% browser zoom on a 1280px viewport, content MUST reflow without loss of information or two-dimensional page scrolling.

## Web interaction states

- Pointer targets MUST be at least `44×44 CSS px`; use `48×48 CSS px` for live logging and other high-frequency actions. Inline text links are exempt from the box minimum but require an adequate line height and visible underline.
- Hover is an enhancement only. Apply it exclusively under `(hover: hover) and (pointer: fine)`; no action, label, or essential information may exist only on hover.
- Pointer press uses the same semantic pressed state as iOS. Coarse-pointer input MUST NOT receive sticky hover styling.
- Every interactive element MUST be keyboard reachable in logical DOM order, operable with standard keys, and visibly focused with a 2px `accent/default` ring plus a 2px Obsidian offset. Never remove the browser focus indicator without this replacement.
- Use semantic HTML controls. `Enter` activates links and buttons; `Space` activates buttons and selectable controls; `Escape` closes a dismissible overlay and returns focus to its invoker; arrow-key behavior follows the applicable ARIA pattern.
- Disabled controls remain non-interactive, use `text/disabled`, and expose their disabled state programmatically. Loading controls retain their accessible name and prevent duplicate submission.

## Composition

Every screen should have:

1. One focal object.
2. One clear primary action.
3. A strong reading order.
4. Controlled negative space.
5. Dense information only where the user needs precision.

Do not place every section inside an isolated floating card. Lists may remain true lists.

---

# 6. Shape and surface language

## Corners

Use continuous iOS corner curves.

```text
radius/s     8 pt
radius/m    12 pt
radius/l    16 pt
radius/xl   24 pt
```

Suggested usage:

- Small chips and thumbnails: 8 pt.
- Buttons and fields: 12 pt.
- Cards and media: 16 pt.
- Sheets and editorial feature panels: 24 pt.

## Borders

- Standard card: 1-point Chalk at 18% opacity.
- Subtle container: 1-point Chalk at 10%.
- Selected card: 1.5-point Send Green at 55–75%.
- Divider: 0.5-point Chalk at 8–10%.
- Do not use ambient shadows in dark mode. On approved iOS frosted surfaces, separation comes only from tint, localized scrim, directional rim, and content underlap.

Elevation comes from:

- Opaque tonal surface contrast for web and dense reading.
- On iOS photo-led compositions only, controlled material depth and layer overlap.
- Stroke strength.
- Temporary pressed scaling.
- Green selection treatment.

## Platform surface rule

Frosted materials are approved only on iOS for photo HUDs, session fact shelves, floating logger/media rails, and navigation or tab chrome that visibly underlaps scrolling content. A material must communicate depth over changing content; it is not a decorative card style. Dense reading surfaces—including settings, forms, long captions, comments, charts, meetup descriptions, and attempt history—remain opaque `surface/card` or Slate.

Web remains an opaque board studio at every breakpoint: no backdrop blur, translucent cards, glass navigation, or frosted emulation. Use Obsidian, Slate, `surface/card`, strokes, and localized opaque gradients over photography.

Never stack frosted surfaces, frost an entire screen, or place a frosted card on an opaque field without content underlap. One composition may have a content-underlapping chrome layer and one photo-attached HUD/fact layer; additional information is flattened into opaque regions.

---

# 7. Navigation architecture

## iOS destinations

The iOS app has four labeled destinations:

1. **Home** — completed-session social feed, plus an in-progress session entry point when applicable.
2. **Log** — start or resume a climbing session and record attempts.
3. **Meetups** — climbing plans, attendance, and meetup detail.
4. **Profile** — identity, session history, statistics, and settings.

Home’s social object is a **completed climbing session**, never an individual send. Sends and failed/stopped attempts remain factual events within that session.

## Web destinations

The web remains the board studio and retains its established board/route-oriented information architecture. Do not force the iOS social-session tabs onto web, and do not add mobile board editing to iOS. Any board/topo authoring and fabricated hold placement shown by the web studio stays web-only.

## iOS tab and navigation chrome

- Use native placement, safe areas, and 44×44-point minimum targets.
- The tab bar may use `material/contentChrome` only while feed photography or scrolling content visibly underlaps it; otherwise resolve to opaque Obsidian.
- Selected icon and label use Send Green; inactive items use muted Chalk; labels are always present.
- Do not use the Boarded mark as a generic Home icon.
- Photo detail navigation may begin with `material/contentChrome` over imagery and resolve to opaque Obsidian before dense reading content reaches it.
- Back, close, and overflow actions retain native placement and 44×44-point targets.
- Material transitions follow scroll position without crossfading text contrast below its required ratio.
---

# 8. Core component patterns

## Primary button

- Minimum height: 52 pt.
- Send Green fill.
- Obsidian semibold label.
- 12-point radius.
- Pressed: darken slightly and scale to 0.98.
- Optional leading icon only when it clarifies the action.

Examples:

- Log attempt
- Start session
- Resume logging
- Save session
- Share session

## Secondary button

- 52 pt height.
- Slate or transparent background.
- 1-point subtle Chalk stroke.
- Chalk label.

## Destructive action

- Semantic danger color.
- Explicit wording.
- Confirmation for irreversible data loss.
- Never styled as a green primary action.

## Chips

- 32–36 pt high.
- Slate background.
- Selected: green-soft background, green stroke and label.
- Use for filters and selectable attributes.
- Do not turn ordinary metadata into pills.

## Text fields

- Minimum height: 52 pt.
- Slate background.
- Persistent or floating label.
- Green focus ring.
- Inline error icon and text.
- Never rely on placeholder-only labeling.

Grade entry should use structured search or selection rather than unconstrained text when possible.

## Standard list row

- Minimum height: 56 pt.
- 16–20 pt horizontal padding.
- Inset hairline divider.
- Use leading domain information and trailing state/action.

A route row might contain:

- Grade.
- Route name.
- Discipline or location.
- Send status.
- Optional disclosure indicator.

---

# 9. Domain-specific components

## Route card

Anatomy:

1. Muted route name.
2. Large italic serif grade.
3. Distance below.
4. Miniature route trace on the right.
5. Bottom attributes with outline icons:
   - Discipline.
   - Rock type.
   - Angle.

The route trace should use:

- Chalk path.
- Green progress or selected nodes.
- Muted gray unresolved segments.
- Sparse geometry.
- Rounded caps.

## Session summary card

Hierarchy:

1. Venue and temporal context.
2. Attempt count.
3. Green vertical gain.
4. Secondary metrics:
   - Time.
   - Routes.
   - Success rate.

Only one metric should receive the green focal treatment.

## Attempt tracker

Rows contain:

- Attempt number.
- Tabular timestamp or duration.
- Outcome icon.
- Explicit outcome label where space permits.
- Optional note or media indicator.

Newest-first works well during an active session. Historical views may use chronological ordering.

## Route topo

The topo language is sparse and diagrammatic:

- A single continuous Chalk line.
- Green current or selected segment.
- Green circular nodes.
- Muted unavailable nodes.
- Explicit Start and Top labels.
- No map-like visual clutter.
- No transit-map styling.

Visual node diameter can remain 8–12 pt, but its interaction target must be at least 44×44 pt.

Provide a list representation for accessibility.

## Metric tile

Anatomy:

1. Outline icon.
2. Large value.
3. Short descriptor.
4. Optional trend indicator.

Examples:

- `842 m` — This week
- `14` — Sessions
- `67%` — Send rate
- `23` — Crag crew

A personal-record tile receives the stronger green border and soft green fill. Ordinary metrics do not.

## Completed-session feed card

The feed card represents one completed climbing session. It is not a send card and must not be generated once per successful route.

Order:

1. Author, avatar, and completed time.
2. One session photograph at `4:5`, `3:2`, or `16:9`, cropped around climbing contact without changing its meaning.
3. Structured factual overlay: venue, duration, attempts, sends, and one featured route with grade.
4. Optional concise caption.
5. Like, comment, and share controls.

On iOS, the facts may occupy one bottom-aligned `material/sessionFactShelf` above `overlay/scrimBottom`; reserve `material/photoHUD` for compact controls or single-line pills. The venue and featured route remain typographic, not pill chips. On web, the same hierarchy uses an opaque tonal block attached below or inset over the photo with an opaque gradient—never glass.

An optional route trace or schematic is permitted only when generated from stored route/session data. It must identify the corresponding featured route and may not invent hold positions, topology, ascent path, or board geometry. Omit it when authoritative data is absent.

---

# 10. Screen patterns

## Home

### Purpose

Home is a photo-led feed of completed climbing sessions. It answers:

- What did my climbing community complete?
- Where and when did they climb?
- What factual session result did they choose to share?
- Is my own session still active?

### Structure

1. Content-underlapping iOS navigation chrome with screen title and profile action.
2. Compact active-session entry, if applicable; this is utility, not a published feed item.
3. Reverse-chronological completed-session cards.
4. Inline loading, end-of-feed, error, and guided empty states.
5. Contextual “Start a session” action.

Each feed card uses exactly one primary photo plus the completed-session factual overlay defined above. A gallery may open from a media count, but the feed surface does not become a carousel and does not collage multiple images.

The active-session entry shows venue, elapsed time, attempts, routes, and Resume logging. It may use `material/floatingRail` only while attached to underlapping session media; otherwise it is opaque Slate.

If Home is empty, explain that completed sessions shared by the climber or their community will appear here and provide “Start a session.” Use the route-line motif only when backed by real route data; otherwise use restrained typography, not a fabricated diagram.

## Route detail

1. Collapsing route photograph or dark topo hero.
2. Route name and location.
3. Large serif grade.
4. Distance and route attributes.
5. Green primary action: Log attempt.
6. Secondary action: View topo or Start session.
7. Topo preview.
8. Session history.
9. Notes and safety/access information.

A sticky action may remain above the home indicator but should disappear when its inline counterpart is visible.

## Live attempt logger

This is the most direct and glove-friendly interface.

1. Venue, current route, and End session action.
2. Tabular elapsed time.
3. Large route grade and route name.
4. Large green Log attempt button.
5. Attempt timeline.
6. Compact session facts.
7. Offline/sync status.

When session media underlaps the controls, venue/time and the logger action rail may use `material/floatingRail`; the attempt timeline and notes remain opaque tonal surfaces. Without underlapping media, all logger surfaces are opaque. High-contrast logger mode always uses opaque Obsidian/Slate and stronger strokes.

Outcome selection is one-handed: Sent, Fell, or Stopped. Each option needs icon and text. Logging works offline; undo appears after accidental logging, and deletion requires confirmation. An individual sent attempt updates the session’s send count but does not create the social share unit.

## Topo explorer

iOS may browse only schematics that already exist as authoritative route data:

1. Route or sector selector.
2. Full interactive canvas.
3. Explicit Start and Top.
4. Chalk path and green selected route.
5. Opaque bottom route information card.
6. Reset view action.
7. Accessible ordered-node list.

Support native pan, pinch, and double-tap zoom. If route geometry is absent, show route facts without a diagram. iOS provides no board/topo editor, hold-placement tool, or inferred geometry. Authoring remains a web board-studio capability.

## Activity and session sharing

Feed cards present a completed session:

- Person and completed time.
- One photo.
- Venue and duration.
- Attempts and sends.
- Featured route and grade.
- Optional concise caption.
- Secondary reactions.

The share composer starts from the just-completed or selected completed session and:

1. Selects or crops one session image.
2. Selects a featured route from routes actually recorded in that session.
3. Previews the structured venue, duration, attempts, sends, and featured route/grade overlay.
4. Optionally includes a data-backed route trace/schematic when authoritative route data exists.
5. Adds alt text and caption.
6. Selects audience.
7. Publishes the whole session.

Do not offer an individual attempt/send as the share object. Upload progress is determinate, failed uploads preserve the draft, and no publish action changes the underlying session record.

## Profile and statistics

1. Avatar and identity.
2. Home crag or gym.
3. One large editorial milestone.
4. Period selector.
5. Metric tiles.
6. Grade progression.
7. Vertical-volume chart.
8. Send-rate value.
9. Discipline distribution.
10. Recent personal records.
11. Standard settings list.

Settings should remain a conventional grouped list. Do not turn privacy, units, and accessibility options into decorative cards.

## Meetup detail

Meetup detail leads with one documentary venue or climbing photo when available, followed by date/time, venue, organizer, attendance state, access notes, and the primary RSVP action. iOS may use `material/sessionFactShelf` for the date/venue facts over that photo, `material/photoHUD` only for a compact control or single-line pill, and `material/contentChrome` while the photo underlaps navigation. Description, attendee list, safety/access notes, and discussion remain opaque tonal reading surfaces. Without a photo, the header is opaque; never fabricate venue imagery or route geometry.

## Session result and share preview

Session Result closes the whole climbing session:

1. Green status eyebrow: `SESSION COMPLETE`.
2. One dominant serif session fact such as vertical gain or a verified new record.
3. Venue, duration, attempts, sends, routes, and success rate.
4. One selected session photo with featured route/grade factual overlay.
5. Optional data-backed route trace/schematic.
6. Share session.
7. Done.

The preview is photo-first and matches the exported composition. On iOS, interactive preview facts may use `material/sessionFactShelf` over `overlay/scrimBottom`; compact photo controls may use `material/photoHUD`, and supporting summaries are opaque. A session without a send remains neutral and respectful: its send count is `0`, not a failure banner. The heading never changes to `SENT`, because completion—not an individual send—is the result and share unit.

## Exported share composition

Export is deterministic and never captures live system blur. Render the selected photo, `overlay/scrimExport`, and Chalk/Send Green text into a flattened image in that order. Include Boarded identity, venue, duration, attempts, sends, and featured route/grade inside the export-safe inset; omit interactive controls, reactions, and material rims. Use embedded display/font assets and preserve the photo crop selected in preview.

If material rendering, photo decoding, or transparency is unavailable, the interactive preview and export both fall back to an opaque Obsidian factual block attached to the photo. If the photo itself is unavailable, export an opaque Obsidian composition with the same facts and no substitute image, schematic, or decorative texture. The preview must visibly match the selected fallback before sharing.

---

# 11. Data visualization

Boarded visualizations should look like climbing paths—not generic business analytics.

## Line charts

- 2-point line.
- 8-point nodes.
- Current or selected segment in green.
- Muted history in gray.
- Minimal horizontal guides.
- Label endpoints and meaningful milestones directly.

## Bar charts

- Slate bars.
- Current selection in green.
- 8-point rounded ends.
- Axes begin at zero.
- Exact value exposed on selection.

## Rings

Use sparingly. A send-rate ring may echo the target-like mark, but it must always include:

- Exact percentage.
- Descriptive label.
- VoiceOver summary.

## Accessibility

Every chart requires:

- A spoken summary.
- Ordered data points.
- Units.
- Comparison period.
- Optional table representation.
- Support for Differentiate Without Color.

---

# 12. Interaction states

## Default

- Chalk content.
- Dark surface.
- Subtle outline.

## Pressed

- Scale to 0.98 for 80–120 ms.
- Slightly stronger stroke or reduced brightness.
- Do not rely only on opacity.

## Focused

- 2-point green outer ring.
- 2-point separation from the control.
- Required for keyboard and switch input.

## Selected

- Green icon or label.
- Optional green-soft background.
- Structural distinction such as a checkmark or stronger stroke.

## Disabled

- Reduced contrast.
- Still-readable label.
- Explain why when the unavailable action is consequential.

## Loading

Use skeletons shaped like the actual content:

- Card silhouettes.
- Route line placeholders.
- Metric text blocks.
- Media rectangles.

A route line may draw progressively, but Reduce Motion replaces this with a static pulse or progress value.

## Empty

Use:

- Simplified route-line motif.
- 32-point serif headline.
- One sentence.
- One useful action.

Examples:

- “No routes boarded yet.”
- “Your first attempt starts here.”
- “Nothing shared from this session.”

## Error

- Inline near the failed content.
- Plain-language explanation.
- Semantic icon and color.
- Clear recovery action.
- Preserve all entered data.

## Offline

Use a persistent compact banner:

- Logging continues locally.
- Queued content is clearly marked.
- Sync resumes automatically.
- The user never loses an attempt because connectivity disappeared.

## Success

Update the actual data first, then show confirmation.

Routine success:

- Compact green confirmation.
- Light haptic.

Completed session:

- Editorial whole-session result screen.
- One data-backed route-line animation only when authoritative geometry exists.
- Optional session sharing.

No confetti is necessary.

---

# 13. Motion and haptics

## Motion tokens

```text
Instant       100 ms
Fast          180 ms
Standard      280 ms
Expressive    420 ms
```

Use:

- Ease-out for entrances.
- Ease-in-out for reordering.
- Restrained spring around 0.82 damping for selection.

### Signature motion

The most recognizably Boarded animation is a route trace drawing from Start to Top over 280–420 ms.

Other appropriate motion:

- Attempt row insertion: 180 ms.
- Metric update: 180 ms crossfade or digit roll.
- Hero-to-detail image transition.
- Selected topo node expansion.
- Bottom sheet presentation using native physics.

Avoid:

- Parallax.
- Continuous glow.
- Looping route animations.
- Pulsing buttons.
- Decorative floating particles.
- Repeated haptics.

## Haptics

- Selection haptic: filters, grades, topo nodes.
- Light impact: logging an attempt.
- Success notification: marking an attempt sent.
- Medium impact: explicit timer start/stop.
- Warning haptic: destructive system action or unrecoverable data risk.

Do not use an error haptic simply because a climber fell.

---

# 14. Imagery direction

Photography should be:

- Documentary rather than aspirational stock.
- Warm and material.
- High in rock and equipment texture.
- Cropped around effort and contact.
- Honest about gyms as well as outdoor crags.

Preferred subjects:

- Hand-to-hold contact.
- Shoe placement.
- Rope and hardware.
- Body position.
- Belay context.
- Chalked texture.
- Route geometry.

Preferred ratios:

- Social or route hero: 16:9 or 3:2.
- Editorial feature: 4:5.
- Detail tile: 1:1.

Avoid text overlays on hands, faces, holds, or equipment. Place localized scrims behind text. An approved iOS photo HUD may frost only its own bounded region above that scrim; web uses an opaque tonal block or measured gradient instead.

---

# 15. Accessibility and outdoor use

- Minimum target: `44×44 pt` on iOS and `44×44 CSS px` on web.
- Prefer `48–52 pt` on iOS and `48–52 CSS px` on web for live logging.
- Body text contrast: at least 4.5:1.
- Large text and meaningful graphics: at least 3:1.
- Never use red and green alone to distinguish outcomes.
- Support Bold Text and Dynamic Type.
- Support Reduce Motion and Reduce Transparency.
- Support Differentiate Without Color.
- Use explicit Voice Control names.
- Provide keyboard and Switch Control focus.
- Allow 30–40% localization expansion.
- Use locale-aware time and measurement units.
- Support multiple climbing grade systems.

## iOS transparency and contrast behavior

- In standard mode and every accessibility combination, verify each final photo composite—not an isolated token or nominal tint—at 4.5:1 for body text and 3:1 for large text and meaningful icons. Measure the rendered photo + scrim + material + tint beneath the foreground across the complete text/icon bounds and against representative worst-case crops.
- If the configured local scrim and material cannot meet those ratios, do not keep increasing blur or invent a per-photo tint. Replace the entire fact area with an opaque Slate or `surface/card` backing and remeasure.
- With **Reduce Transparency**, replace every material with an opaque Obsidian or Slate surface: `photoHUD` → Obsidian, `sessionFactShelf` and `floatingRail` → Slate, `contentChrome` → Obsidian. Keep layout, hierarchy, and controls unchanged; use the existing 18% Chalk stroke and retain localized scrims only where text still overlaps a photo.
- With **Increase Contrast**, prefer the same opaque replacements for dense fact shelves and the active logger. If a bounded photo HUD remains material, use `material/rimHighContrast`, raise its Obsidian tint to 72%, and remeasure the final composite to the same 4.5:1 body and 3:1 large-text/icon thresholds.
- With both settings enabled, the opaque Reduce Transparency mapping wins; do not preserve blur merely to communicate depth.
- Bold Text must not cause fact values to collide or truncate. Differentiate Without Color adds explicit labels/icons to sent, failed, selected, and attendance states.

For outdoor legibility:

- Avoid critical text below 15 pt.
- Offer a high-contrast logger mode.
- Increase effective topo-node hit areas.
- Prevent screen dimming only during an explicitly active session.

Example VoiceOver route summary:

> “Redpoint Ridge, grade 5.12a, 27 meters, sport, limestone, overhang, not yet sent. Actions available: log attempt, open topo, save route.”

---

# 16. Anti-patterns

Do not:

- Replace the editorial serif with a generic bold sans.
- Use serif typography for forms or dense utility content.
- Turn every number and icon green.
- Use pure black and pure white.
- Add neon gradients, generic glass cards, stacked frosted panels, glowing borders, or heavy shadows. The only glass exception is the explicitly approved, bounded iOS material categories over underlapping content.
- Put every list row inside an isolated card.
- Use pills for static metadata.
- Make route diagrams resemble transit maps.
- Use inaccessible tiny topo nodes.
- Encode outcomes using color alone.
- Place text directly on detailed rock without contrast treatment.
- Use generic summit or hiking stock photography.
- Reconstruct or casually distort the Boarded mark.
- Override native back gestures.
- Use unlabeled tab icons.
- Nest sheets.
- Add confetti to routine actions.
- Treat falls as system errors.
- Require connectivity to record attempts.
- Discard a share draft after upload failure.
- Make sharing a prerequisite for saving progress.

---

# 17. Figma library structure

A complete designer handoff should contain:

## Foundations

- Core and semantic colors.
- Shared dark palette plus distinct iOS material and opaque-web surface specifications.
- Serif, sans, and tabular text styles.
- Spacing tokens.
- Compact and regular grids.
- Radii and strokes.
- Icon sizing.
- Motion durations.
- Accessibility annotations.

## Component sets

Build stateful components for:

- Buttons.
- Fields.
- Chips.
- Tabs.
- Navigation bars.
- Route cards.
- Session summaries.
- Metric tiles.
- Attempt rows.
- Route list rows.
- Data-backed topo paths and nodes.
- Completed-session feed cards and share previews.
- Banners.
- Sheets.
- Empty states.
- Loading skeletons.
- Error states.
- Chart primitives.

Every component should show:

- Default.
- Pressed.
- Focused.
- Selected.
- Disabled.
- Loading.
- Error.
- Success.
- Compact width.
- Regular width.
- Standard Dynamic Type.
- Accessibility Large Dynamic Type.
- Long localized copy.
- Increase Contrast.
- Reduce Transparency.
- Reduce Motion where relevant.

## Prototype flows

The minimum connected prototype should cover:

```text
Home session feed
→ Live Logger
→ Log Attempt
→ Session Result
→ Share Session

Home session feed
→ Completed Session Detail

Meetups
→ Meetup Detail

Profile
→ Session History
→ Statistics
→ Personal Record
```

## iOS screenshot acceptance

Capture every named screen on **iPhone 16 Pro portrait at 402-pt logical width** and on a **regular-width iPad in portrait**, at **standard Dynamic Type** and **Accessibility Large**, once with normal settings and once with Reduce Transparency + Increase Contrast. Every screenshot must show semantic use of Obsidian, Slate, Chalk, and Send Green; no clipped/truncated essential text; 4.5:1 body and 3:1 large-text/icon contrast against every final photo composite; safe-area clearance; and opaque accessibility fallbacks. Review semantic token assignment and measured contrast, not exact blended pixel colors: system materials, display gamut, photograph, and compositing make their rendered pixels intentionally differ from the source token values.

| Screen | Standard acceptance | Accessibility Large acceptance |
|---|---|---|
| Home | Completed-session feed is immediately legible; each card has one photo and the five-part factual overlay; bounded HUD/chrome frost only where content underlaps | Facts reflow to one per row; essential facts move to the opaque continuation when the photo is busy; actions remain 44×44 pt |
| Active logger | Venue/time and media rail may frost over session media; attempt timeline is opaque; primary log action is unmistakable | Logger facts stack without clipping; timeline reading order is intact; high-contrast/opaque mode retains 48–52 pt actions |
| Session result/share preview | Whole-session `SESSION COMPLETE` hierarchy, one photo, venue/duration/attempts/sends/featured route-grade, and export preview match | Factual block moves below photo as opaque continuation; preview still matches flattened export fallback and all facts remain visible |
| Meetup detail | Photo header may carry bounded fact HUD; description, access notes, attendees, and discussion are opaque | Date, venue, organizer, and RSVP remain first in reading order; long details reflow without internal scrolling |
| Profile | Identity/photo may use content-underlapping chrome; history, statistics, and settings are opaque tonal surfaces | Identity and milestone wrap; metrics become rows; settings labels and values remain complete and ordered |

The final test for every design decision:

> Does this feel like a refined climbing instrument with an editorial soul—or like a generic dark fitness app?

If it feels generic, reduce decoration, strengthen the serif/sans hierarchy, restore physical imagery, and give the meaningful route or achievement one unmistakable focal position.