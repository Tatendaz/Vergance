# Feature: Phase 2 — calibration & on-screen gaze cursor

**Branch:** feat/phase-2-calibration
**Date:** 2026-06-27

## Summary
Adds a 9-dot calibration that learns the gaze→screen mapping, and a Run mode that draws a
smoothed on-screen gaze cursor from the live webcam gaze feature — the first genuinely
interactive gaze experience.

## Motivation
Phase 1 proved the pupil-offset gaze feature is stable but uncalibrated. Phase 2 learns the
`(gx,gy) → screen` mapping so the raw feature becomes an actual on-screen cursor.

## What changed
- **GazeKit:** `CalibrationSession` + `CalibrationTargets.ninePoint` — per-dot **median**
  capture (discarding saccade-settling frames), quadratic-ridge fit via `CalibrationFitter`,
  and **RMS-pixel** error. 4 new unit tests (16 total, green).
- **apps/macOS:**
  - `CalibrationViewModel` — orchestrates the 9-dot capture over the existing `WebcamSensor`,
    fits the model, and runs the live mapping + One Euro smoothing.
  - `CalibrationView` — the 9-dot capture screen (settle → capture per dot, progress, RMS).
  - `GazeCursorView` — the Run-mode gaze cursor + RMS readout + Recalibrate.
  - `ContentView` — Probe / Calibrate / Run mode switch (the Phase 1 probe is preserved).

## Notes
Windowed (no screen-capture entitlement) — calibration dots and the cursor map within the
app window. Accuracy is region-level (the webcam ceiling); keep the head still during
calibration and **Recalibrate** on reposition. One Euro params (`minCutoff 1.0, beta 0.5`)
are tuned for the normalized signal and easy to adjust. Manually validated: calibration
completes and the cursor tracks gaze region reasonably ("pretty decent tracking").
