# Tasks — Head-Aware Calibration

## 1. GazeKit core — HeadCompensator

- [ ] 1.1 Add `HeadCompensator` to `Sources/GazeKit/`: init from calibration-capture head poses/spans (baseline = per-axis means), delta computation against the baseline, and a zero-initialized bounded additive linear correction (`corrected = mapped + clamp(J·d)`)
- [ ] 1.2 Add the internal stability window (I-DT style dispersion + min-duration) and gated online learning: per-sample regularized update regressing the **negative** anchor deviation against the relative head delta (so `J` cancels head-induced motion), with forgetting factor and per-step cap; no updates during saccades, below the confidence threshold, or while the residual alarm is active
- [ ] 1.3 Add the residual drift alarm with a trust-gated envelope: starts at the legacy 0.12 rad threshold with zero trust and widens toward the hard limit only as residual reduction is demonstrated; also alarms on correction-cap saturation, persistent within-window residual, or span-ratio breach — exposed as a single flag
- [ ] 1.4 Add reset semantics: a new successful baseline replaces the old one and zeroes the learned correction; a failed fit leaves both untouched
- [ ] 1.5 Unit tests mapping 1:1 to the spec scenarios (synthetic streams only): zero-knowledge identity, unlearned alarm matches the legacy threshold, learned correction reduces head-correlated error, cap clamping, saccade-only streams learn nothing, learning frozen while drifted, alarm on extreme drift / span breach / compensated-drift-no-alarm, reset on recalibration, full path driven without any platform framework
- [ ] 1.6 `swift build` and `swift test` green, package still Xcode-free

## 2. macOS app wiring

- [ ] 2.1 `CalibrationViewModel`: on a successful fit, construct the `HeadCompensator` from the capture-window poses/spans and delete the ad-hoc `calibrationHeadPose`/`calibrationSpan`/threshold state it replaces
- [ ] 2.2 Run path becomes map → compensate → smooth → fixate; `headDrifted` now reads the compensator's residual flag (dim-cursor, 0.5-confidence, recalibrate-prompt semantics unchanged)
- [ ] 2.3 `xcodegen generate` + macOS app builds; Calibrate → Run flow works end-to-end with the compensator in place
- [ ] 2.4 On-device validation: hold gaze on a target while drifting the head slowly — cursor stays on target and no alarm inside the envelope; fast/extreme head motion still alarms; tune envelope, cap, and forgetting constants and record them (One Euro precedent)

## 3. Docs & gate

- [ ] 3.1 ROADMAP §3: update the drift bullet from alarm-only to compensate-with-residual-alarm
- [ ] 3.2 Add `docs/features/` and `docs/summaries/` entries per the repo pre-push gate

## 4. Stretch (optional) — AirPods head-motion fusion

- [ ] 4.1 GazeKit: pure-function fusion math (AirPods→head mount-offset estimation, complementary blend of camera-absolute + gyro-relative rotation, camera-clamped output) + unit tests on synthetic quaternion/Euler streams
- [ ] 4.2 App target: `HeadphoneMotionSensor` wrapping `CMHeadphoneMotionManager` (authorization, connect/disconnect, ~25 Hz delivery), `NSMotionUsageDescription` added via `project.yml`; CoreMotion types converted to plain values at the boundary
- [ ] 4.3 Feed the fused pose through the compensator's input contract; coast the head delta for ≤ ~1 s of face loss at reduced confidence; behavior with AirPods absent/unauthorized is bit-identical to core
- [ ] 4.4 On-device validation with AirPods: stabilization during fast head motion, face-loss coasting, and graceful degradation on disconnect
