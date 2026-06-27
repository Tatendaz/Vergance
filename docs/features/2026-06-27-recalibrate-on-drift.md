# Feature: Recalibrate-on-drift (head-movement robustness)

**Branch:** feat/recalibrate-on-drift
**Date:** 2026-06-27

## Summary
Detects when the head has moved away from the calibration pose — by **rotation**
(yaw/pitch/roll) or **distance** (inter-eye span) — and flags it: in Run the gaze cursor
dims, a "recalibrate" banner appears, and fixation events are tagged lower confidence, so a
stale calibration never silently feeds Claude bad gaze.

## Motivation
Webcam calibration is head-pose sensitive — the pupil-offset feature mixes gaze with head
position, so moving the head degrades accuracy. This is the cheap half of the fix: *detect*
the drift (head pose is already captured) rather than compensate. Head-pose-aware
calibration (compensation) and the iPhone TrueDepth sensor (the real fix) come next.

## What changed
- **GazeKit:** `HeadPose.angularDistance(to:)` (rotation drift); `GazeSample.headSpan` +
  `GazeFeatures.interEyeSpan` — a gaze-independent head-distance proxy (eye centers move
  apart as you lean in, together as you lean back). 3 new tests (21 total).
- **macOS:** `CalibrationViewModel` captures a head-pose + span baseline during calibration
  and flags `headDrifted` in Run when rotation **or** distance exceeds a threshold;
  `GazeCursorView` dims the cursor and shows a recalibrate banner; drifted fixations get
  confidence 0.5.

## Notes
Thresholds tunable (pose ~7°, distance ±10% span). Head *turns* validated live to trigger
the banner; the inter-eye-span **distance** check (this change, for lean-in/out) is
compile-verified — merging on CI/review green, easy to tune after.
