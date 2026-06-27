# Feature: Phase 3 — fixation event stream

**Branch:** feat/phase-3-fixations
**Date:** 2026-06-27

## Summary
Turns the live calibrated gaze into the first real Claude-facing event stream: a
`session_start` plus `fixation` events, detected by the dispersion-threshold detector and
visualized on the Run screen.

## What changed
- **GazeKit:** `FixationEvent(_ fixation:)` convenience that builds the Claude-facing event
  from a geometric `Fixation`. 2 new tests (18 total, green).
- **apps/macOS:**
  - `CalibrationViewModel` — in Run mode, feeds the smoothed calibrated gaze into a
    `FixationDetector`, emits a `session_start` on entering Run, and records completed
    fixations as `FixationEvent`s (capped in-memory log).
  - `GazeCursorView` — overlays recent fixations as translucent discs sized by dwell, with
    a live `Fixations: N` / `last dwell` readout.

## Notes
Fixations are geometric (centroid + dwell); resolving them to named UI elements is a later
phase. Detector thresholds (>150 ms within a small radius) live in GazeKit. Manually
validated: settling on a spot then moving off records a fixation — the marker and count
appear when the dwell cluster ends (per `FixationDetector`), while saccades produce none
("very good tracking"). Known follow-up: webcam calibration is head-pose
sensitive — recalibrate-on-drift + head-pose-aware calibration are the next changes.
