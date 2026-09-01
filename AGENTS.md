# AGENTS.md

## Engineering Principles & Development Rules

- **Forward-Facing Trajectory:** Do NOT retain backward-compatibility layers, deprecation shims, legacy aliases, or dead code. Maintain zero unused or orphaned code in active modules.
- **Clean Cutover & Pruning:** Aggressively delete superseded implementations, legacy fallbacks, orphaned scripts, and obsolete configuration files instead of archiving or hoarding them. Backwards compatibility does not matter for this stage of development.
- **Repository Structure & Economy:** Keep repository layout clean, condensed, and modular. Every file, module, and script MUST serve a single, clear, canonical purpose for upcoming development.
- **No Speculative Abstractions:** Prefer simple, direct implementations over premature abstractions, unused parameter flags, or speculative fallbacks.
- **Verification Requirement:** Every refactor or deletion MUST be verified by running the relevant test suite or smoke scenario before completing the change.

## Boarded Campaign Repository Policy

- **Main orchestration only:** Main MUST plan, decompose, dispatch, coordinate, and integrate independently reviewed worker commits/reports. Main MUST NEVER directly author or edit source, tests, config, docs, or assets.
- **Isolated mutations:** Every repository mutation MUST be performed by a worker in a dedicated isolated git worktree.
- **Integration ownership:** Main is the sole integration decision owner.
- **Active designer lane:** A designer lane MUST stay active for the campaign and MUST review every packet.
- **Designer ownership:** The designer owns every user-facing screen, component, interaction, responsive treatment, accessibility treatment, and screenshot review.
- **Mixed UI/data packets:** Mixed UI/data packets MUST pair a designer with the implementation specialist.
- **Non-UI specialist work:** SQL, security, build, and repository mechanics remain with `task-high`, `security-reviewer`, and `reviewer` specialists, respectively, but each packet still requires designer approval marked `no visual impact` or surface approval.
- **Generated brand imagery:** `designer-loop` is mandatory for generated brand imagery.
- **Rendered-image review:** `vision` is mandatory for independent rendered-image review.
- **Design contract:** `docs/design-language.md` is mandatory reading for every designer packet.
