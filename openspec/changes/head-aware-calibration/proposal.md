# Head-Aware Calibration

## Why

Webcam gaze accuracy degrades as soon as the head leaves the pose held during calibration —
and today Vergance *knows* this (it computes head-pose drift on every frame) but uses that
knowledge only as an alarm: dim the cursor, halve fixation confidence, ask for a full 9-dot
recalibration. Every natural head shift costs the user a ~15-second re-run. ROADMAP §3
explicitly deferred the fix ("head pose is captured into the feature vector so a later
version can compensate in-model without re-architecting") — this change is that later
version: convert the drift **alarm** into a drift **correction**, learned online, with the
alarm retained for residual drift the correction cannot absorb.

## What Changes

- **New GazeKit component `HeadCompensator`** — applies a bounded, additive correction to
  the calibrated screen point as a function of the head's delta (yaw/pitch/roll and
  head-span ratio) from the calibration baseline. Zero-initialized: until it has learned
  anything, output is bit-identical to today's pipeline.
- **Online learning during fixations** — within a fixation window the eye is presumed
  still, so movement of the *mapped* point that correlates with head-pose movement is
  head-induced bias; the compensator regresses this online (regularized, with forgetting)
  and applies it thereafter. No new calibration UI, no extra dots, no user-visible
  training step.
- **Calibration baseline moves into GazeKit** — the mean head pose + head span over the
  calibration capture (currently ad-hoc state in `CalibrationViewModel`) becomes the
  compensator's baseline, making the whole correction path headless-testable and reusable
  by the iOS/TrueDepth path later.
- **Drift alarm becomes residual** — the *meaning* of `headDrifted` changes; its
  downstream wiring does not. Today it activates on any pose delta past ~7°; after this
  change it reports drift the correction cannot absorb (envelope exceeded, correction cap
  saturated, or residual error still high). The envelope is trust-gated: an unlearned
  compensator keeps today's ~7° activation exactly, and it widens only as the learned
  correction demonstrably holds residual error down. Downstream consumers (dimmed cursor,
  0.5 fixation confidence, recalibrate prompt) bind to the flag unchanged.
- **Pluggable head-motion input (seam only in core)** — the compensator consumes head
  pose/span from the `GazeSample` stream through a narrow input contract, so a
  higher-quality head-rotation source can substitute later without touching the math.
- **Stretch (optional, off the critical path): AirPods head-motion fusion** — a
  `HeadphoneMotionSensor` in the macOS app target (`CMHeadphoneMotionManager`, ~25 Hz)
  fused with the webcam head pose (camera = absolute anchor, gyro = clean relative
  rotation) for stabilization during fast head motion and short face-loss coasting.
  CoreMotion stays out of the GazeKit package.

No breaking changes: `CalibrationModel`, the event schema (`session_start`, `fixation`,
`utterance`), and the sensor protocol are untouched.

## Capabilities

### New Capabilities

- `head-compensation`: head-aware correction of calibrated gaze — baseline capture at
  calibration time, bounded online-learned correction of the mapped screen point during
  runs, fixation-gated learning, residual drift alarm, and the head-pose input contract
  that future sources (TrueDepth, AirPods) plug into.

### Modified Capabilities

<!-- none — element-resolution, utterance-fusion, voice-activity, and speech-capture
     consume the (now-corrected) cursor and the same headDrifted flag with unchanged
     semantics; no existing spec-level requirement changes. -->

## Impact

- **GazeKit (core):** new `HeadCompensator` (+ unit tests); `HeadPose.angularDistance`
  stays and is reused for the residual alarm. Pure math, no new dependencies,
  `swift test` still Xcode-free.
- **apps/macOS:** `CalibrationViewModel` — baseline capture and `headDrifted` computation
  delegate to the compensator; the run path becomes map → compensate → smooth → fixate.
  `GazeCursorView`/`CalibrationView` drift UI unchanged in shape.
- **Stretch only:** new `HeadphoneMotionSensor.swift` in `apps/macOS` (CoreMotion),
  `NSMotionUsageDescription` in `project.yml`, fusion stage in GazeKit fed by plain values
  (no CoreMotion types in core).
- **Docs:** ROADMAP §3 drift bullet updated from alarm-only to compensate+residual-alarm;
  `docs/features/` + `docs/summaries/` entries per the repo gate.
- **Events/API:** none — `rmsErrorPx`, event payloads, and `GazeSensor` are unchanged.
