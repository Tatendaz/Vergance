## Context

Phase 4 ships the `utterance` event, but `UtteranceFuser` labels each gaze target with a geometric
placeholder — `regionID(for:)` maps the fixation centroid to a 3×3 screen cell (`r1c1`). The
Claude-facing payoff ("look at `cta-primary`, say 'make this bigger'") needs **named** elements.

The primitives for surface (a) already exist in `Sources/GazeKit/ElementMap.swift`: `Rect`
(normalized, origin top-left, `contains(ScreenPoint)`), `Element` (`id`/`role`/`label`/`rect`),
and `ElementMap` (`hitTest` — last match wins — and `target(for:)` — builds a `GazeTarget`). What's
missing is the **wiring**: the fuser and fixation path don't consult an `ElementMap`, and nothing
populates one from the live UI.

Constraints (CLAUDE.md / ROADMAP):
- **GazeKit stays platform-agnostic** — no AVFoundation/Vision/Speech/ARKit. Resolution is pure
  logic over `ElementMap`, `swift test`-able; element *registration* (SwiftUI frames) is app-side.
- **Backward-compatible** — Phase 4 callers and tests must keep working untouched.
- **One coordinate space** — element rects and gaze points must both be screen-normalized `[0,1]`,
  origin top-left, or hit-testing is meaningless (the analogue of Phase 4's single-clock rule).

## Goals / Non-Goals

**Goals:**
- Resolve a gaze `ScreenPoint`/fixation centroid to a named `Element` via the active surface's
  `ElementMap` (topmost-wins), with a geometric region-id fallback when nothing is hit.
- Route `UtteranceFuser` gaze targets **and** `FixationEvent.target` through one resolution path so
  they agree on identity.
- Keep ranking/aggregation/`primaryTarget` byte-for-byte identical; only target identity changes.
- Register the macOS Run screen's elements into an `ElementMap` and surface named targets live.

**Non-Goals:**
- **Surface (b) browser DOM** and **(c) macOS Accessibility API** resolution — later Phase 5
  sub-surfaces (roadmap §6 #4); they add requirements to this same capability behind the same API.
- **New geometry primitives** — `Rect`/`Element`/`ElementMap` already exist; this is wiring.
- **Multi-display / window-relative gymnastics** — single main display for v1.
- **Speech / trigger changes** — untouched.

## Decisions

### 1. Resolution in GazeKit, registration in the app
The resolve-or-fall-back logic lives in `GazeKit` over the existing `ElementMap`, fully
unit-tested, mirroring how `UtteranceFuser`/`FixationDetector` already live there. Turning live
SwiftUI element frames into normalized `Rect`s is app-side (`apps/macOS`), where the view geometry
lives. *Alternative:* resolve in the app against live views — rejected; untestable without Xcode and
violates the core-agnostic rule.

### 2. One resolution path for fixations and utterances
A single helper (point → `GazeTarget` via `ElementMap`, region fallback on miss) is consumed by
both `FixationEvent.target` and the fuser's per-fixation labeling. *Why:* a fixation event and the
utterance that overlaps it must name the **same** element, or Claude sees contradictory targets.

### 3. Region-id fallback, never drop
On an empty map or a no-hit point, resolution returns the geometric region id (today's
`regionID`) with a `region` role — it does not drop the candidate or return nil. *Why:* preserves
Phase 4's "speech without gaze still emits" guarantee, keeps non-element gaze informative, and
makes the empty-map path reproduce Phase 4 output exactly. *Alternative:* drop unresolved fixations
— rejected; loses information and breaks backward compatibility.

### 4. `fuse(...)` takes a defaulted `elements: ElementMap = ElementMap()`
The new input defaults to an empty map, so every existing Phase 4 call site and test compiles and
behaves identically (empty map → region fallback). *Alternative:* required parameter — rejected;
needless break for zero benefit.

### 5. Topmost-(last-)registered wins
Reuse `ElementMap.hitTest`'s existing "last match wins" semantics; the app registers elements in
paint/z-order so the visually-topmost element under the gaze is the one resolved.

### 6. Normalized rects from SwiftUI `GeometryReader`
The app reads each registered element's frame in the global coordinate space and normalizes it to
`[0,1]` against the same screen bounds the gaze pipeline maps into, so element rects and gaze
points share one space (Decision: one coordinate space). Re-read on layout changes so rects track
the live UI.

## Risks / Trade-offs

- **Coordinate-space mismatch (view-local vs window vs screen)** → normalize element frames through
  the *same* screen bounds the gaze→`ScreenPoint` mapping uses; verify by running the app and
  confirming a looked-at button resolves to its id (the checkpointed app-validation step).
- **Stale rects on resize/scroll** → re-register from `GeometryReader` on layout change; v1 targets
  a static Run screen, so churn is low.
- **Overlapping / mis-registered rects** → topmost-wins is deterministic; keep registration in
  paint order and keep the demo element set small and non-overlapping.
- **Empty map before the app registers anything** → region fallback means the pipeline still emits
  meaningful (region-level) targets — graceful degradation, identical to Phase 4.

## Migration Plan

Additive and defaulted; no event-schema types change and no Phase 4 behavior changes under an empty
map. Ship the GazeKit resolution + fuser wiring first (verified by `swift test`), **checkpoint**,
then the app registration + Run-screen readout (verified by running the app). Rollback is removing
the registration and the `elements:` argument — Phase 4 behavior is what remains.

## Open Questions

- The concrete element set + ids to register on the Run screen for the demo (`cta-primary`, …) —
  pick a small, representative, non-overlapping set during the app-wiring task.
- Whether to also resolve through the live `ElementMap` for the post-hoc session summary regions —
  deferred to Phase 8 (heatmap mode); not needed for the live pointer.
