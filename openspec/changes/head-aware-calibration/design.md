# Design — Head-Aware Calibration

## Context

The run pipeline today is `CalibrationModel.map(gx, gy)` → One Euro filter → fixation
detection (`CalibrationViewModel.handle`). Head pose is used twice, both passively:

- During calibration capture the app collects per-frame head poses/spans and stores their
  mean as `calibrationHeadPose`/`calibrationSpan` (app-side state).
- At run time `HeadPose.angularDistance(to:)` against that baseline sets `headDrifted`
  (> 0.12 rad or ±10 % span), which dims the cursor, halves fixation confidence, and
  prompts a recalibrate.

The quadratic calibration model is fit from 9 dots captured with a deliberately still
head, so the mapping is only valid near the calibration pose. Head motion shifts the raw
pupil-offset features and the mapped point walks off the true gaze target — a systematic,
head-correlated bias, which is exactly what a correction can absorb.

## Goals / Non-Goals

**Goals:**
- Correct the mapped gaze point as a function of head delta from the calibration baseline,
  learned online with zero user-visible training.
- Behave bit-identically to today — cursor **and** alarm — until the correction has
  learned something (safe default).
- Keep the alarm for drift the correction cannot absorb; keep all downstream semantics.
- Keep every new piece of math in GazeKit, platform-agnostic and `swift test`-covered.

**Non-Goals:**
- No new calibration choreography (no "now move your head" step).
- No persistence of the learned correction across app sessions (it encodes one sitting's
  geometry; recalibration resets it).
- No pixel-precision claims — this widens the usable head envelope at region/element
  accuracy, per the ROADMAP accuracy bar.
- No iOS companion changes (the TrueDepth path plugs into the same seam later).
- AirPods fusion is stretch: designed here, not required for acceptance.

## Decisions

### 1. Correction form: bounded additive linear correction, zero-initialized

`corrected = mapped + J · d`, where `d = [Δyaw, Δpitch, Δroll, Δspan]` and `J ∈ ℝ²ˣ⁴` is
learned online. `‖J · d‖` is clamped to a max-correction cap; `J = 0` at start.

Delta conventions: the pose deltas are per-axis shortest signed angular differences from
the baseline, wrapped to (−π, π]. `Δspan = span/baselineSpan − 1` is defined only when
`baselineSpan > 1e-6` (the guard the current span check already uses); with no valid
baseline span, the span column of `d` is zero and span-based alarming is disabled.

- *Why not head terms inside the calibration regression?* During calibration the head is
  intentionally still — head features have ~zero variance in the training set, so their
  coefficients are unidentifiable without a head-motion calibration dance (worse UX).
- *Why not a hardcoded geometric/VOR gain?* The gain depends on user↔screen geometry we
  don't know (distance, screen size). Learning it costs nothing and adapts per sitting.
- *Why linear?* Within the deltas we tolerate (≲ 15°) the induced feature shift is
  locally smooth; first-order captures the dominant term with data we can actually
  collect in seconds. Quadratic needs more data than natural head drift provides.

### 2. Learning signal: stable-gaze windows, compensator-internal

During a window where the (corrected) gaze point is dispersion-stable for ≥ 150 ms, the
eye is presumed parked on one target. Let `e = mapped − anchor` be a sample's mapped-point
deviation from the window anchor and `Δd = d − d_anchor` its head delta relative to the
anchor's. If the corrected point is to stay put while the head moves, then from
`corrected = mapped + J · d` we need `J · Δd ≈ −e` — the regression target is the
**negative** deviation, so a learned `J` cancels head-induced motion rather than
reinforcing it. Per-sample normalized-gradient update with forgetting:

```
J ← (1 − λ) · J + η · ((−e) − J · Δd) · Δdᵀ / (‖Δd‖² + ε)
```

with forgetting factor `λ`, learning rate `η`, and the per-step change capped.

The compensator maintains its **own internal stability window** (same I-DT idea as
`FixationDetector`) rather than coupling to the event-facing detector: the detector's
output timing (emit-on-break) and its role in the event schema stay untouched, and the
learner can use slightly laxer bounds. Slow natural head drift — the common case that
today trips the alarm — survives dispersion checks and is precisely the data we learn
from; fast head turns break windows, contribute nothing, and fall to the alarm.

Learning is gated off when: the residual alarm is active (out of trusted envelope), the
sample is low-confidence, or the window is too short.

### 3. Pipeline order: map → compensate → smooth → fixate

Correction applies to the raw mapped point, before the One Euro filter, so smoothing
doesn't lag corrections and the fixation detector consumes the same final signal as
today. Corrections evolve continuously (linear in a smoothly-changing `d`), so they don't
present saccade-like steps to the filter.

### 4. Alarm becomes residual, with a trust-gated envelope

`headDrifted` (name kept) now means "beyond what compensation absorbs":
- pose delta beyond the *effective* correction envelope (see below), or
- the correction cap is saturated, or
- recent within-window residual error stays high (correction isn't working), or
- span drift beyond threshold (leaning is a distance change the 2-D correction handles
  worst — keep the existing ±10 % check).

The effective envelope is **trust-gated** so an unlearned compensator never loosens the
alarm: it starts at the legacy threshold (0.12 rad) and widens toward the hard limit
(~2×) only in proportion to a trust score in [0, 1] derived from recent within-window
residual reduction. With `J = 0` (fresh start, or after reset) trust is 0, the envelope
equals the legacy threshold, and alarm behavior is exactly today's — which is what makes
the bit-identical-until-learned claim true for the alarm as well as the cursor.

Downstream (dim cursor, 0.5 fixation confidence, recalibrate prompt) binds to the flag
unchanged.

### 5. Baseline and drift math move into `HeadCompensator` (GazeKit)

`HeadCompensator` is initialized with the calibration-capture head poses/spans (the app
already collects them) and owns: baseline mean, delta computation, correction, learning,
and the residual flag. `CalibrationViewModel` sheds its ad-hoc baseline state; the whole
path becomes headless-testable with synthetic pose streams. `CalibrationSession` is
untouched.

### 6. Input contract: plain values, any source

The compensator consumes `(headPose, headSpan, t)` as plain values — it never knows the
source. TrueDepth later, or fused AirPods pose, substitutes without touching the math.
No platform frameworks enter GazeKit.

### 7. Stretch: AirPods fusion (optional layer, app target)

- `HeadphoneMotionSensor` (macOS app target) wraps `CMHeadphoneMotionManager`
  (~25 Hz attitude + rotation rate; requires `NSMotionUsageDescription` and device
  support: AirPods Pro/3/4/Max, some Beats).
- Known sensor limits drive the design: yaw drifts (no magnetometer), the reference frame
  is arbitrary per session, the ear-mount offset changes per insertion, Bluetooth adds
  ~50–100 ms latency. Therefore the webcam pose is always the absolute anchor; a slow
  complementary filter estimates the AirPods→head offset online, and only the
  high-frequency relative rotation from the gyro is blended in.
- Uses: stabilize pose input during fast head motion (landmark jitter rejection) and
  coast the head delta for ≤ ~1 s of face loss (marking reduced confidence).
- Fusion math (offset estimation, complementary blend) lives in GazeKit as pure
  functions on plain quaternion/Euler values; CoreMotion type conversion happens at the
  app boundary. Absent/unauthorized/disconnected AirPods → behavior identical to core.

## Risks / Trade-offs

- [Learning from a false anchor — smooth pursuit or slow target motion mistaken for a
  stable window] → conservative gates (min duration, dispersion bound, per-step cap,
  forgetting) and the global correction cap bound worst-case damage; a bad `J` washes out
  after a few good windows.
- [Shared failure modes — the head-pose estimate and gaze features come from the same
  landmarks, so occlusion/low light can corrupt both coherently] → skip low-confidence
  samples; freeze learning whenever the residual alarm is active; regularization keeps
  `J` small under noisy evidence.
- [Compensation masks genuine degradation so users never recalibrate] → the alarm still
  fires on saturation/high residual; calibration RMS reporting is unchanged; the
  correction cap limits how much degradation can be silently absorbed.
- [Filter interplay — a correction step momentarily reads as motion to One Euro] →
  corrections are continuous and bounded; no discrete jumps by construction.
- [AirPods yaw drift or mount-offset error steering the fused pose] → webcam stays the
  anchor; the fused pose is clamped to a small deviation from the camera pose; stretch
  scope means none of the core acceptance depends on it.

## Migration Plan

Purely additive; ships dark by default (zero-initialized correction = today's behavior).
Rollback = remove the compensator call site in `CalibrationViewModel`; no data or schema
migration exists. Tuning constants (envelope, caps, forgetting) follow the One Euro
precedent: defaults chosen from synthetic tests, then tuned during on-device validation.

## Open Questions

- Tuning values (correction cap, hard envelope, forgetting factor) — resolved during the
  on-device validation task, not blocking implementation.
- Whether span (Δspan) earns its column in `J` in practice or stays alarm-only — decided
  by the same validation; the design supports either by zeroing the column.
