## Why

Phase 4 emits `utterance` events, but their `gazeTargets` carry a **geometric placeholder**
id — `UtteranceFuser.regionID(for:)` labels each fixation with the 3×3 screen cell it lands in
(`r1c1`). That is not the named element the whole product promises: *"the user looked at
`cta-primary` while saying 'make **this** bigger'."* Phase 5 turns coordinates into named
elements. The roadmap (§6 #4) fixes the staging — **(a) own canvas → (b) browser DOM →
(c) Accessibility API** — and this change delivers surface **(a)**, the foundation the other two
build on behind the same resolution API.

## What Changes

- **New `element-resolution` capability**: resolve a gaze `ScreenPoint` / fixation centroid to a
  named `Element` on the active surface via that surface's `ElementMap` (topmost-match-wins
  hit-test). When nothing is hit — empty map, or the point lands on bare canvas — fall back to the
  existing geometric region id, so a target is **never dropped**. (`Element` / `Rect` /
  `ElementMap` with `hitTest` + `target(for:)` **already exist** in
  `Sources/GazeKit/ElementMap.swift`; this change wires them into the event path, it does not
  introduce new primitives.)
- **`UtteranceFuser.fuse(...)` consumes an `ElementMap`**: a new `elements:` input (defaulted to an
  empty map) resolves each overlapping fixation's target through element-resolution, so
  `gazeTargets` now carry **named ids + role + label** instead of `region` cells. Overlap
  classification, per-id aggregation, score-based ranking, and the `primaryTarget` heuristic are
  **unchanged** — only the identity of a target changes. With an empty map every fixation falls
  back to its region id, reproducing Phase 4 behavior exactly (**non-breaking**).
- **`FixationEvent.target` resolved through the same map**: the always-nil placeholder in
  `FixationEvent.init(_:target:confidence:)`'s call sites is replaced by an element-resolution
  lookup, so fixation events and utterances agree on element identity.
- **macOS Run-mode wiring**: register the Run screen's on-screen elements as normalized `Rect`s
  (SwiftUI `GeometryReader` → screen-normalized frames) into an `ElementMap`, and feed it into
  `CalibrationViewModel` so live fixations and utterances carry named ids. Validated by running the
  app — **checkpointed** after the headless GazeKit core, exactly as the Phase 4 app wiring was.

**Scope boundary.** Only surface **(a)** the app's own canvas. Surfaces **(b) browser DOM** and
**(c) macOS Accessibility API** are later Phase 5 sub-surfaces (roadmap §6 #4) and out of scope
here; they will add requirements to the same `element-resolution` capability without changing the
fuser API. No speech-capture or trigger changes.

## Capabilities

### New Capabilities
- `element-resolution`: resolve a gaze point / fixation centroid to a named `Element` on the
  active (own-canvas) surface via its `ElementMap` — topmost-match-wins hit-test, with a geometric
  region-id fallback when nothing is hit.

### Modified Capabilities
- `utterance-fusion`: `fuse(...)` accepts the active surface's `ElementMap` and resolves
  `gazeTargets` to named elements (id/role/label) through element-resolution; ranking, aggregation,
  and `primaryTarget` are unchanged, and an empty map preserves the Phase 4 region-id behavior.

## Impact

- **GazeKit**: `UtteranceFuser` gains an `ElementMap` parameter and the resolve-or-fall-back wiring;
  a small resolution helper for single points (fixation events) over the existing
  `ElementMap.hitTest` / `target(for:)`; new unit tests. Stays platform-agnostic — no
  AVFoundation/Vision/Speech/ARKit imports. `Element`/`Rect`/`ElementMap` are already present.
- **apps/macOS**: element registration on the Run screen (`GeometryReader` → normalized rects),
  `CalibrationViewModel` wiring so fixations/utterances resolve to named ids, and a Run-screen
  readout that shows the named target. App-target code, validated by running the app.
- **Event schema**: no type changes — `GazeTarget` already carries `id`/`role`/`label`; only the
  values flowing into them change.
- **Non-breaking**: the new `fuse(...)` parameter is defaulted; the empty-map path reproduces Phase
  4 output byte-for-byte. Rollback is removing the registration + the `elements:` argument.
