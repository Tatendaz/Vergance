# Feature: Phase 1 — Webcam probe

**Branch:** feat/phase-1-webcam-probe
**Date:** 2026-06-27

## Summary
The first runnable slice: a macOS diagnostic that opens the webcam, runs Vision
face-landmark detection, and shows a live overlay of pupils / eye-corners / lips plus a
head-pose and gaze-feature readout. De-risks whether webcam landmark tracking is stable
enough before building calibration on top.

## Motivation
On macOS there is no ARKit, so gaze must be reconstructed from 2-D Vision landmarks. The
single biggest unknown is whether Vision's pupil/eye landmarks are stable enough under
real lighting. This phase makes that visible before investing in the calibration regression.

## What changed
- **GazeKit feature math** (platform-agnostic, unit-tested):
  - `Point2D` / `EyeLandmarks` / `FaceLandmarks` — the sensor→pipeline seam.
  - `GazeFeatures`: pupil-offset gaze feature `(gx, gy)`, mouth-aspect-ratio, and
    `FaceLandmarks → GazeSample` assembly.
  - 4 new unit tests (12 total, all passing).
- **macOS webcam probe** (`apps/macOS/`):
  - AVFoundation camera capture + Vision `VNDetectFaceLandmarks` detection → `FaceLandmarks`
    (with Vision→top-left coordinate conversion).
  - `WebcamSensor: GazeSensor` producing a `GazeSample` stream.
  - SwiftUI probe UI: live preview, landmark overlay, and a head-pose / gaze-feature /
    MAR / FPS readout.
- **CI:** `pr-gate.yml` — server-side gate on `macos-15` (free for public repos):
  `swift build` + `swift test` + a `docs/features` entry check.

## Notes
No calibration yet — gaze features are raw. Accuracy is region-level by design (webcam).
Live testing requires granting camera permission in the GUI. Next: Phase 2 (9-dot
calibration → on-screen gaze cursor).
