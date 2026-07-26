# Feature: Head-aware calibration — OpenSpec proposal

**Branch:** feat/head-aware-calibration
**Date:** 2026-07-22

## Summary
Proposal to convert the head-pose drift **alarm** into a drift **correction**. Today the run
pipeline computes the head's delta from the calibration pose on every frame but only uses it to
dim the cursor, halve fixation confidence, and prompt a 9-dot recalibration
([recalibrate-on-drift](2026-06-27-recalibrate-on-drift.md)); every natural head shift costs a
~15-second re-run. The proposed `HeadCompensator` (GazeKit) applies a bounded, zero-initialized
linear correction to the mapped gaze point as a function of that same delta, learned online during
stable-gaze windows — no new calibration choreography, no user-visible training. The alarm stays,
re-scoped to *residual* drift the correction cannot absorb. **This PR is the proposal only** —
ROADMAP §3 anticipated exactly this upgrade ("a later version can compensate in-model without
re-architecting"); implementation follows in a separate PR.

## What changed
- **OpenSpec:** new change `head-aware-calibration` with all four artifacts:
  - `proposal.md` — why: alarm → correction; one new capability, no breaking changes.
  - `design.md` — correction form (`corrected = mapped + clamp(J·d)`, zero-initialized),
    fixation-anchored online learning with an internal stability window, map → compensate →
    smooth → fixate ordering, residual alarm conditions, and why head terms can't go in the
    calibration regression (the head is deliberately still during capture — unidentifiable).
  - `specs/head-compensation/spec.md` — 6 requirements / 14 scenarios: baseline capture,
    zero-knowledge output identical to today, capped correction, fixation-gated learning,
    residual alarm, reset on recalibration, source-agnostic head-pose input.
  - `tasks.md` — 4 groups: GazeKit core + tests, macOS wiring + on-device tuning, docs/gate,
    and optional AirPods head-motion fusion (`CMHeadphoneMotionManager`) as stretch.
- **No code changes** — GazeKit, apps, and tests are untouched (48/48 green on this branch).

## Notes
- Origin: an investigation into AirPods head tracking. Conclusion: the webcam already delivers
  head pose in every `GazeSample`; making the pipeline *use* it is the high-value step, and it
  benefits every user. AirPods (~25 Hz, Bluetooth latency, yaw drift, no eye data) can only
  refine the head signal, so they're scoped as an optional stretch layer anchored to the camera.
- Zero-initialized correction means shipping it dark is safe: until learning occurs, output is
  bit-identical to the current pipeline.
- Tuning constants (envelope, cap, forgetting) are deliberately left to the on-device validation
  task, following the One Euro precedent.
