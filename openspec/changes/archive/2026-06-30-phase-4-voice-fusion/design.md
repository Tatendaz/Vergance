## Context

Phases 0–3 produce a calibrated, smoothed gaze point and a geometric fixation stream
(`FixationDetector` → `FixationEvent`), wired into Run mode by `CalibrationViewModel`. The
Claude-facing `Utterance` and `VoiceActivity` types already exist in `GazeKit/Events.swift`, but
nothing produces them. Phase 4 adds the producers: speech, a lip-derived voice-activity signal,
and the fusion that turns "what was said" + "what was looked at" into one `Utterance`.

Constraints that shape the design:
- **Core stays platform-agnostic** (CLAUDE.md): `GazeKit` must not import AVFoundation / Speech /
  Vision. Those live in `apps/macOS`. GazeKit gets only pure, `swift test`-able logic.
- **Privacy posture** (ROADMAP §6 #10): raw audio/frames never leave the device; only the
  semantic `Utterance` does.
- **Fusion is temporal**: speech window timestamps and gaze/MAR sample timestamps must live on
  the same monotonic clock, or overlap classification is meaningless.

## Goals / Non-Goals

**Goals:**
- Capture speech via push-to-talk and produce `text` + `speechConfidence` + a precise window.
- Derive a mouth-aspect-ratio (MAR) voice-activity signal from existing lip landmarks and reduce
  it to `VoiceActivity` over the window.
- Fuse the speech window with the fixation stream into a ranked `Utterance` with a
  `primaryTarget` heuristic, implemented as pure logic in `GazeKit` with unit tests.
- Surface the emitted `Utterance` in Run mode.

**Non-Goals:**
- **Lipreading / visual speech recognition** — MAR is timing/emphasis only.
- **Named element resolution** (`cta-primary`) — that is Phase 5. Phase 4 ranks fixations and
  labels targets with whatever id the fixation stream carries today (geometric/region placeholder).
- **Always-listening / wake word** — push-to-talk only this phase.
- **iOS / TrueDepth** — Phase 7.
- **Streaming partial-result UI / barge-in** — final result per hold is enough.

## Decisions

### 1. Layering: pure logic in GazeKit, capture in the app
The mouth-aspect-ratio helper (`GazeFeatures.mouthAspectRatio`) with `MouthSample` /
`VoiceActivity`, and `UtteranceFuser` (window + fixations → `Utterance`), go in `GazeKit` —
no platform imports, fully unit-tested, mirroring how
`CalibrationFitter` / `FixationDetector` already live there. `SpeechRecognizer` (Speech +
AVFoundation) and the Vision-landmark→MAR feed live in `apps/macOS`.
*Alternative considered:* put the fuser in the app for direct access to live state — rejected; it
would be untestable without Xcode and violates the core-agnostic rule.

### 2. Push-to-talk over always-listening
Hold-to-talk defines an exact `[tStart, tEnd]` window, which is what fusion needs, and is the
privacy-friendly default (ROADMAP #8). It also sidesteps endpointing/VAD complexity.
*Alternative:* MAR-gated always-on VAD — deferred; more moving parts, weaker privacy story.

### 3. On-device recognition
`SFSpeechAudioBufferRecognitionRequest.requiresOnDeviceRecognition = true`. Honors the privacy
posture. If `SFSpeechRecognizer.supportsOnDeviceRecognition` is false for the locale, surface an
error rather than silently using the network path.
*Trade-off:* on-device accuracy can trail server recognition; acceptable for the privacy guarantee.

### 4. Single monotonic clock for fusion
The speech window's `tStart`/`tEnd` are stamped from the **same capture timeline** as
`GazeSample.t` / fixations / MAR samples — not from audio-buffer host time. The app owns one
monotonic clock (the one already feeding `GazeSample.t`) and reads it on PTT press/release.
*Risk addressed:* audio engine time and Vision frame time would otherwise drift apart and break
overlap classification.

### 5. MAR definition
MAR = vertical lip separation ÷ horizontal mouth width, from the lip-contour landmarks the Vision
detector already extracts. Dividing by mouth width makes it roughly invariant to head distance.
Closed mouth → near 0.
*Alternative:* `jawOpen` blendshape — only exists on ARKit (iOS); MAR is the documented webcam
proxy (ROADMAP §2 table).

### 6. Fusion scoring
Each candidate fixation is classified `during` / `leading` / `trailing` against the window with
lead/trail margins, then scored as `classWeight + dwellWeight·dwell`. `gazeTargets` is sorted by
score. `primaryTarget` is the top id only if its score beats the runner-up by `primaryMargin`,
else nil (hand Claude the ranked list to disambiguate). Margins/weights are named constants in
GazeKit, like the existing `FixationDetector` thresholds, so they are tunable and test-pinned.

### 7. Run-mode integration
`CalibrationViewModel` keeps a bounded ring buffer of recent fixations and MAR samples (both
already flow through it in Run mode). On PTT release it slices the buffer to the window, calls
`UtteranceFuser`, appends the `Utterance` to the in-memory event log, and publishes it for the
Run screen readout (text + primary target + ranked alternatives + jaw-open peak).

## Risks / Trade-offs

- **Clock skew between audio and gaze** → Decision 4: one monotonic clock, window stamped from it,
  not from audio host time.
- **On-device recognition unavailable (locale/hardware)** → check `supportsOnDeviceRecognition`,
  surface an authorization/availability error, emit no `Utterance`.
- **Placeholder gaze target ids (no Phase 5 yet)** → `gazeTargets` ids are geometric/region
  stand-ins; ranking and `primaryTarget` are still meaningful ("which fixation"), and named
  resolution drops in behind the same fuser API in Phase 5.
- **MAR noise / spurious openness** → MAR is informational only in PTT mode (it does not gate
  recognition), so noise degrades emphasis stats at worst; light smoothing on the sample stream.
- **Permission friction** → explicit authorization request on first PTT and clear denied-state
  messaging on the Run screen.

## Migration Plan

Additive and behind push-to-talk; no existing types or events change. Ship GazeKit logic first
(verified by `swift test`), then the app capture + wiring. Rollback is removing the PTT control and
the new sources — Phases 0–3 behavior is untouched.

## Open Questions

- Exact lead/trail margins and score weights — start from `FixationDetector`-scale values
  (hundreds of ms) and tune against manual Run-mode trials.
- PTT control surface: keyboard hold vs. on-screen button for v1 (keyboard hold is simplest).
