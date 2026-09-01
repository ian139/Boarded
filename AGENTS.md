# AGENTS.md

## Engineering Principles & Development Rules

- **Forward-Facing Trajectory:** Do NOT retain backward-compatibility layers, deprecation shims, legacy aliases, or dead code. Maintain zero unused or orphaned code in active modules.
- **Clean Cutover & Pruning:** Aggressively delete superseded implementations, legacy fallbacks, orphaned scripts, and obsolete configuration files instead of archiving or hoarding them. Backwards compatibility does not matter for this stage of development.
- **Repository Structure & Economy:** Keep repository layout clean, condensed, and modular. Every file, module, and script MUST serve a single, clear, canonical purpose for upcoming development.
- **No Speculative Abstractions:** Prefer simple, direct implementations over premature abstractions, unused parameter flags, or speculative fallbacks.
- **Verification Requirement:** Every refactor or deletion MUST be verified by running the relevant test suite or smoke scenario before completing the change.

## Boarded Campaign Repository Policy

- **Main orchestration only:** Main MUST plan, decompose, dispatch, coordinate, and decide integration. Main MUST NOT author or edit packet content in source, tests, config, docs, or assets; workers exclusively author packet content in dedicated isolated worktrees. Main MAY perform only the local integration mutation needed to apply an independently reviewed packet, including cherry-picking, applying, or merging its worker commit.
- **Isolated authoring:** Every packet-content mutation MUST be performed by a worker in a dedicated isolated git worktree. Main's local cherry-pick, apply, or merge of an approved worker packet is the sole exception and does not transfer authorship.
- **Integration ownership:** Main is the sole integration decision owner and the only role permitted to perform the packet's local integration mutation.
- **Packet:** A packet is one bounded worker assignment and its complete handoff: scope, declared affected platforms, changed paths or report, verification evidence, and designer verdict. Splitting implementation and review does not create an approval exemption.
- **Platform applicability:** Before dispatch, every packet scope MUST declare `iOS`, `web`, or `both` from the changed user contract. A shared user-facing concept, semantic token, identity, backend field shown to users, or change matching an existing surface affects both platforms unless the packet explicitly proves that no counterpart impact exists. Platform-specific implementation mechanics MAY remain one-platform.
- **Active designer lane:** An active designer lane is a named designer who remains reachable from dispatch through the pre-integration gate, owns the current design contract, and reviews every packet before integration.
- **Designer ownership:** The designer owns every user-facing screen, component, interaction, responsive treatment, accessibility treatment, and screenshot review.
- **Mixed UI/data packets:** Mixed UI/data packets MUST pair a designer with the implementation specialist.
- **Non-UI specialist work:** SQL, security, build, and repository mechanics remain with `task-high`, `security-reviewer`, and `reviewer` specialists, respectively, but each packet still requires a designer verdict.
- **Designer verdict forms:** A designer verdict MUST be exactly one of `approved`, `changes requested: <actionable findings>`, or `no visual impact: <reason>`. Silence, an emoji, or a generic acknowledgement is not approval.
- **No-visual-impact report:** This report is valid only when a packet cannot alter rendered pixels, interaction behavior, responsive layout, accessibility presentation, or user-facing copy. It MUST name the reviewed paths and explain why no visual surface can change.
- **Pre-integration gate:** Before Main integrates a packet, its scope and evidence MUST be complete, its designer verdict MUST be `approved` or a valid `no visual impact` report, and every `changes requested` finding MUST be resolved and re-reviewed.
- **Rendered screenshot evidence:** Every UI packet MUST include screenshots rendered from the changed implementation for every platform declared affected and at each required compact/regular or mobile/desktop width. Mockups, source inspection, and snapshots from before the change do not qualify. Evidence MUST cover the changed states and identify viewport/device, appearance, and route or scenario.
- **Generated brand imagery:** `designer-loop` is mandatory for generated brand imagery.
- **Rendered-image review:** `vision` is mandatory for independent rendered-image review.
- **Design contract:** `docs/design-language.md` is mandatory reading for every designer packet.
