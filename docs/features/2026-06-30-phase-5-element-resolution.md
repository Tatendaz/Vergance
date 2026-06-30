# Feature: Phase 5 — element resolution (own canvas)

**Branch:** feat/phase-5-element-resolution
**Date:** 2026-06-30

## Summary
Turns gaze coordinates into **named elements**. `utterance` and `fixation` events now carry real
element ids (`cta-primary`, …) with role/label, resolved against the active surface's `ElementMap`,
instead of the geometric `r1c1` region placeholders Phase 4 emitted. This is staged surface **(a)
the app's own canvas** (roadmap §6 #4); browser-DOM (b) and Accessibility-API (c) surfaces extend
the same capability later.

## What changed
- **GazeKit** (platform-agnostic, +12 tests → 48 total green):
  - `ElementMap.resolve(_:dwellMs:overlap:confidence:)` — the single resolution path: the
    containing element's id/role/label (topmost-match-wins via the existing `hitTest`), else a
    geometric region-id fallback (`UtteranceFuser.regionID`) so a candidate target is never dropped.
  - `UtteranceFuser.fuse(...)` gained a defaulted `elements: ElementMap = ElementMap()` input and
    now resolves each overlapping fixation through `resolve`, grouping/ranking by the **resolved
    id**. Overlap classification, aggregation, and the `primaryTarget` heuristic are unchanged — an
    empty map reproduces Phase 4 output byte-for-byte (backward-compatible).
  - `FixationEvent(_:resolvedBy:confidence:)` — a new initializer that resolves `target` from the
    fixation centroid via the same path, so fixation events and utterances agree on identity.
- **apps/macOS:**
  - `CalibrationViewModel` — holds the active surface's `ElementMap` (`registerElements(_:)`), and
    threads it into both fixation-event resolution and `fuse(...)` (snapshotting it alongside the
    other inputs before the speech `await`).
  - `GazeCursorView` — renders **Vergance's own canvas**: four named, look-at-able tiles
    (`headline`, `cta-primary`, `cta-secondary`, `media`) at fixed normalized rects that are both
    drawn and registered, so what you see is what gaze resolves against. A tile highlights under the
    live cursor / last resolved target, and the utterance card shows the named target
    (`→ cta-primary (Get started)`).

## Notes
- `Element` / `Rect` / `ElementMap` (`hitTest`, `target(for:)`) already existed in GazeKit — Phase 5
  is wiring + tests, not new primitives.
- For our **own** canvas the demo elements declare their normalized rects directly (drawn and
  registered from the same constant), which keeps element rects and the gaze cursor in one
  coordinate space with no `GeometryReader` round-trip — the coordinate-mismatch risk the design
  flagged. External surfaces (b/c) will build their maps from their own trees.
- The empty-map region fallback keeps the "speech without gaze still emits" guarantee and means
  uncalibrated/unregistered gaze still produces region-level targets.
- Out of scope (future Phase 5 sub-surfaces): browser-DOM and Accessibility-API resolution.
- Hardened the region fallback against non-finite gaze coordinates and the fuser's voice-activity
  window against an inverted `[tStart, tEnd]` span (both from CodeRabbit, with regression tests).
  Pre-existing push-to-talk concurrency findings are tracked as a separate follow-up.
- Verification: `swift test` 48/48 green; the macOS app `BUILD SUCCEEDED` via headless `xcodebuild`
  (Xcode 26.5); **validated on-device** — looking at a tile while speaking produces that tile's
  named id as the utterance's `primaryTarget`.
