## 1. GazeKit core — element resolution (headless, `swift test`)

- [x] 1.1 Add a resolution helper that maps a `ScreenPoint` to a `GazeTarget` via an `ElementMap`: on hit, carry the element's `id`/`role`/`label`; on miss or empty map, fall back to the geometric region id (`regionID`) with a `region` role. This is the single path reused by the fuser and fixation events.
- [x] 1.2 Thread `elements: ElementMap = ElementMap()` through `UtteranceFuser.fuse(...)`; replace the per-fixation `regionID(for:)` call with the resolution helper so the aggregation key and each `gazeTarget`'s `id`/`role`/`label` come from resolution. Keep overlap classification, aggregation, ranking, and `primaryTarget` unchanged.
- [x] 1.3 Add a `FixationEvent` initializer/overload that resolves `target` from the fixation centroid via the helper + `ElementMap` (replacing the always-nil placeholder); update the stale "element-resolution lands in a later phase" comment in `FixationEvent+Fixation.swift`.
- [x] 1.4 Unit tests (element-resolution): point inside one element → named target; overlapping rects → topmost (last-registered) wins; point on bare canvas → region target with `region` role; empty map → region id for every point.
- [x] 1.5 Unit tests (utterance-fusion): overlapping fixation inside an element → that element's id + role/label on the `gazeTarget`; two glances at the same element aggregate into one target (summed dwell, count 1); empty map reproduces the Phase 4 region-id output (regression pin).
- [x] 1.6 `swift build && swift test` all green; confirm GazeKit still imports no AVFoundation/Vision/Speech/ARKit.

## 2. macOS app — Run-screen element registration + wiring (needs Xcode/GUI; CHECKPOINT before starting)

- [x] 2.1 Define a small, representative, non-overlapping set of named Run-screen elements (e.g. `cta-primary`, …); read each one's global frame via `GeometryReader` and normalize to a screen `[0,1]` `Rect` in the same coordinate space as the gaze `ScreenPoint`.
- [x] 2.2 Assemble the normalized rects into an `ElementMap` in `CalibrationViewModel`, refreshed on layout change.
- [x] 2.3 Pass the live `ElementMap` into `fuse(...)` and into fixation-event resolution so live utterances and fixations carry named ids.
- [x] 2.4 Run-screen readout: show the resolved named target (id/label) on the utterance card and the fixation overlay.
- [x] 2.5 Build (`xcodebuild`) and validate on-device: look at a registered element while speaking → the utterance's `primaryTarget`/`gazeTargets` carry that element's id.

## 3. Docs, spec sync & gate

- [x] 3.1 Add a `docs/features/` entry for Phase 5 surface (a) element resolution.
- [x] 3.2 Add the session/summary entry for this session.
- [x] 3.3 Update the ROADMAP Phase 5 row to reflect surface (a) done, with (b) browser DOM and (c) Accessibility API still pending.
- [x] 3.4 `openspec validate phase-5-element-resolution --strict` passes.
