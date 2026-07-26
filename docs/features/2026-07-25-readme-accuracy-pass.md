# Feature: README accuracy pass — tense, status, and prerequisites

**Branch:** docs/readme-slim
**Date:** 2026-07-25

## Summary
The README was wrong in both directions at once: it described seven unbuilt things in the
present tense, and it called a 1,814-line app with 48 green tests "pre-alpha / scaffolding."
This pass verifies every claim against source, moves the phantom ones into future tense with
an explicit phase marker, restores the shipped-phase status, and adds the prerequisites,
`git clone` step and contributing gate that were missing. 191 → 143 lines when written
(205 → 151 after reconciling the two merges from main), mostly by cutting content that
`ROADMAP.md` already owns.

## What changed

### Seven present-tense claims that had no implementation
Each is now framed as roadmap, with the phase named:

| Claim | Verified against | Now reads as |
|---|---|---|
| iOS companion streams TrueDepth gaze over Bonjour | `apps/iOS/` is 36 lines / 2 files; `apps/iOS/ContentView.swift:16` renders "Phase 7 — not wired yet"; no `import ARKit` or `import Network` in the tree | "**phase 7, not wired yet.** Planned: …" |
| macOS is the receiver for the phone stream | no `NWListener` / `NWBrowser` / `NWConnection` anywhere | folded into the same phase-7 sentence |
| webcam and iPhone are interchangeable, side-by-side | one `GazeSensor` conformer: `apps/macOS/WebcamSensor.swift:12` | "interchangeable **by design**. One exists today — the macOS webcam; the iPhone is phase 7." |
| shipped as a Claude Code skill `/vergance` | `.claude/skills/` holds five openspec skills, none named vergance; `ROADMAP.md:165` = phase 6 | "handing them to an agent … is **phase 6**" |
| intent "is delivered to Claude" | zero hits for `JSONEncoder` / `write(to` / `stdout` / `URLSession` / `print(` across `Sources/` + `apps/`; events are `@Published` state (`apps/macOS/CalibrationViewModel.swift:39-42,61-62`) | lead: "Today that lands as a structured event inside the app; the hand-off to a coding agent is Phase 6." |
| post-hoc heatmap as a shipping surface | `SessionSummary` (`Sources/GazeKit/Events.swift:151`) is never constructed, including in tests; `ROADMAP.md:167` = phase 8 | "**Phase 8**: the type exists, the aggregation and the viz don't." |
| element resolution canvas → DOM → AX | only canvas; `Sources/GazeKit/ElementMap.swift:37-39` and `apps/macOS/GazeCursorView.swift:256` both say the rest is future; no `AXUIElement` / `WebKit` in the tree | "Browser-DOM and Accessibility-API surfaces are staged after it." |

### Status, in the other direction
- Dropped "pre-alpha / scaffolding" from `README.md` and `ROADMAP.md:7`. Replaced with the
  real state: phases 0–4 done, 5(a) validated on-device, 48 green tests.
- Restored the `✅` markers the README's phase table had stripped, and **added the missing
  ones to `ROADMAP.md`'s own table** — phases 1, 2 and 3 carried no marker there either,
  despite each having a shipped `docs/features/` entry and phase 4 (which depends on all
  three) being marked done.
- Removed "the webcam probe, calibration, and fixation work are in active development."

### Getting started
- Added a **Prerequisites** block under the install heading: macOS 14+ (a *build* requirement
  from `Package.swift:6`, previously stated only as tech-stack trivia), Swift 5.9+
  (`Package.swift:1`), Xcode 15+/XcodeGen for the app targets, and the camera / mic / speech
  permissions the app asks for.
- Added the missing `git clone` step — the section previously opened on `swift build`.
- "Core package (no Xcode)" → "no Xcode **project**", since a toolchain is still required.
- `brew install xcodegen` now names a Homebrew-free alternative.

### Duplication
Cut the byte-identical ASCII component diagram (`ROADMAP.md:49-64`, md5-verified), the
webcam-vs-TrueDepth signal table (`ROADMAP.md:93-99`), the pipeline block
(`ROADMAP.md:105-114`), the phase table's deliverable column, the `## Tech stack` section
(now covered by Prerequisites + Architecture) and the repo tree (its paths are folded into
the Architecture bullets). All of it is linked, not lost — the README already declared
ROADMAP the source of truth.

### Added
- A **Contributing** section stating that `.github/workflows/pr-gate.yml` fails any PR
  without a `docs/features/*.md` entry, and that `docs/summaries/` is gitignored and not
  required. This was documented in zero user-facing files when written; `CONTRIBUTING.md`
  §3 (landed since, via the CI-hardening PR) now covers it in full, and the README
  paragraph stays as the short version.
- A new lead: "**Voice can't point. Gaze can.**" The deixis idea was the sharpest thing in
  the project and was buried in the last clause.
- An honest note that there are no screenshots yet.

## Notes
- The lead says "hold the talk button", not "talk key": push-to-talk is a `DragGesture` on a
  SwiftUI button (`apps/macOS/GazeCursorView.swift:102-121`), and there is no
  `keyboardShortcut` bound to it.
- The Platforms badge pointed at `#tech-stack`; it now points at `#prerequisites`. Whole-tree
  grep for inbound `README.md#` links returns zero, so nothing *in this repository* pointed at
  the old anchor. That is the whole of what the grep establishes — a bookmark or an off-repo
  page linking `#tech-stack` would still break, and this change accepts that.
- Preserved verbatim (diff-verified against `origin/main`): `### Honest accuracy bar`,
  `### Non-goals (v1)`, the `cta-primary` example event, the bolded privacy line, and all
  four badge images.
- Verification: `swift test` — 48 tests, 0 failures, exit 0. Docs only; no source touched.
- Post-merge reconciliation (review pass): the docs landing page (`docs/index.html`,
  merged in from main) still said "Pre-alpha · scaffolding" and repeated the same
  present-tense claims this pass removed from the README — its status pill, Status
  section, meta descriptions, surface/feature bullets and FAQ now match the corrected
  status. `SECURITY.md`'s "there are no releases" predated the v0.1.0 release
  (2026-07-18) and is corrected separately. iOS 17+ joined the README prerequisites,
  since the Platforms badge advertises it and links there. 48 tests re-verified green
  on the merged branch.
