# AGENTS.md

## Engineering Principles & Development Rules

- **Forward-Facing Trajectory:** Do NOT retain backward-compatibility layers, deprecation shims, legacy aliases, or dead code. Maintain zero unused or orphaned code in active modules.
- **Clean Cutover & Pruning:** Aggressively delete superseded implementations, legacy fallbacks, orphaned scripts, and obsolete configuration files instead of archiving or hoarding them. Backwards compatibility does not matter for this stage of development.
- **Repository Structure & Economy:** Keep repository layout clean, condensed, and modular. Every file, module, and script MUST serve a single, clear, canonical purpose for upcoming development.
- **No Speculative Abstractions:** Prefer simple, direct implementations over premature abstractions, unused parameter flags, or speculative fallbacks.
- **Verification Requirement:** Every refactor or deletion MUST be verified by running the relevant test suite or smoke scenario before completing the change.
