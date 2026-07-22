# head-compensation — Delta Spec

## ADDED Requirements

### Requirement: Calibration captures a head baseline
The system SHALL record the head pose and head span of every frame captured during a
calibration run, and on a successful model fit SHALL store their per-axis means as the
head baseline for the new model. A failed fit SHALL leave any previously stored baseline
and model untouched.

#### Scenario: Baseline set on successful fit
- **WHEN** a 9-dot calibration completes and the model fit succeeds
- **THEN** the head baseline equals the per-axis mean of the capture-window head poses and the mean of the capture-window head spans

#### Scenario: Failed fit preserves the working baseline
- **WHEN** a recalibration's fit fails (under-determined or singular)
- **THEN** the prior model and its head baseline remain in effect

### Requirement: Head-conditioned gaze correction
The system SHALL apply an additive correction to each calibrated screen point, computed
as a bounded linear function of the head's delta (yaw, pitch, roll, span ratio) from the
head baseline, before runtime smoothing. With no learned evidence the correction SHALL be
exactly zero, and the correction magnitude SHALL never exceed a fixed cap.

#### Scenario: Zero-knowledge output is unchanged
- **WHEN** a run starts with a freshly fit model and no learning has occurred
- **THEN** every corrected point equals the uncorrected mapped point

#### Scenario: Learned correction counteracts head drift
- **WHEN** the correction has been learned from a synthetic stream whose mapped points shift proportionally to head yaw while true gaze is fixed
- **THEN** corrected points land closer to the true gaze target than uncorrected points for head deltas within the correction envelope

#### Scenario: Correction is capped
- **WHEN** the head delta is large enough that the linear correction would exceed the cap
- **THEN** the applied correction is clamped to the cap

### Requirement: Learning is gated to stable-gaze windows
The system SHALL update the correction only from samples inside stable-gaze windows —
periods where the corrected gaze point stays within a dispersion bound for at least a
minimum duration — starting from zero, with a forgetting factor and a bounded per-update
step. The system SHALL NOT update the correction while the residual drift alarm is
active or from samples below a confidence threshold.

#### Scenario: Saccades contribute nothing
- **WHEN** the gaze stream contains only rapid point-to-point jumps with no dwell meeting the minimum duration
- **THEN** the correction remains exactly zero

#### Scenario: Slow head drift during dwell is learned
- **WHEN** the gaze dwells on one target while the head pose drifts slowly within the correction envelope
- **THEN** subsequent corrections reduce the head-correlated error of the mapped point

#### Scenario: No learning while drifted
- **WHEN** the residual drift alarm is active
- **THEN** correction updates are suspended until the alarm clears

### Requirement: Residual drift alarm
The system SHALL expose a drifted flag that reports head drift the correction cannot
absorb — when the pose delta exceeds the effective correction envelope, the correction
cap is saturated, the within-window residual error remains above threshold, or the head
span ratio exceeds its threshold. The effective envelope SHALL be trust-gated: with no
learned evidence it SHALL equal the legacy drift threshold, widening toward the hard
limit only as the learned correction demonstrates residual reduction. Downstream
consumers SHALL receive the same alarm semantics as before (reduced cursor prominence,
fixation confidence 0.5, recalibration prompt).

#### Scenario: Unlearned compensator alarms exactly like today
- **WHEN** no learning has occurred and the head pose delta exceeds the legacy drift threshold
- **THEN** the drifted flag is true, matching pre-compensation behavior

#### Scenario: Compensated drift does not alarm
- **WHEN** the head has drifted within the correction envelope and the learned correction holds the residual error below threshold
- **THEN** the drifted flag is false

#### Scenario: Extreme drift alarms
- **WHEN** the head pose delta exceeds the hard correction envelope
- **THEN** the drifted flag is true regardless of the learned correction

#### Scenario: Leaning alarms via span
- **WHEN** the head span ratio deviates from the baseline beyond the span threshold
- **THEN** the drifted flag is true

### Requirement: Recalibration resets the correction
A successful recalibration SHALL reset the learned correction to zero and replace the
head baseline with the new capture's baseline.

#### Scenario: Fresh fit, fresh correction
- **WHEN** a recalibration completes successfully after a period of learning
- **THEN** the correction is zero and the baseline reflects the new capture

### Requirement: Source-agnostic head-pose input
The compensator SHALL consume head pose and head span as plain values carried by the
sample stream, independent of which sensor produced them, and the core package SHALL NOT
import any platform sensor framework for this capability.

#### Scenario: Synthetic streams drive the full path
- **WHEN** unit tests feed a synthetic sequence of (gaze point, head pose, head span, time) tuples
- **THEN** baseline capture, correction, learning, and the residual alarm are all exercised without any sensor or platform framework
