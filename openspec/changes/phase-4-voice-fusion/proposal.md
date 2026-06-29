## Why

Phases 0–3 give us calibrated gaze and a live fixation stream, but no way for the user to
*express intent*. The `utterance` event — recognized speech fused with **what the user was
looking at** — is the deixis-resolving core object the whole product is built around
("make **this** bigger"). Phase 4 is the phase that finally produces it. The `Utterance` and
`VoiceActivity` Codable types already exist in `GazeKit/Events.swift`; nothing captures audio
or emits them yet.

## What Changes

- **Push-to-talk speech capture** (macOS app): `SFSpeechRecognizer` + `AVAudioEngine`, gated by
  a hold-to-talk control, producing recognized `text` + `speechConfidence` + a capture window
  `[tStart, tEnd]`. On-device recognition only (`requiresOnDeviceRecognition`) to honor the
  "raw signals never leave the device" posture.
- **Mouth-aspect-ratio (MAR) voice-activity**: compute a mouth-openness signal from the lip
  landmarks the Vision detector already extracts, sampled per frame; reduce the samples inside
  the speech window to a `VoiceActivity` (`jawOpenMean`, `peak`). This is *audio-for-words,
  lips-for-timing* — **not** lipreading.
- **Utterance fusion** (GazeKit, platform-agnostic + unit-tested): given a speech window, the
  fixation stream, and the voice-activity samples, rank `gazeTargets` by temporal overlap with
  the window (classified `during` / `leading` / `trailing`) and dwell, choose a `primaryTarget`
  best-guess, and build the `Utterance`.
- **Run-mode wiring** (`CalibrationViewModel`): push-to-talk opens a capture window; fixations
  and MAR samples landing in that window feed the GazeKit fuser; the emitted `Utterance` is
  appended to the in-memory event log and surfaced on the Run screen (recognized text +
  primary target + ranked alternatives).
- **Permissions**: microphone + speech-recognition usage strings and an authorization flow.
- **Non-breaking**: no existing type changes; the existing `Utterance` shape is the target.

**Scope boundary.** Resolving a gaze point to a *named* element (`cta-primary`) is Phase 5.
Phase 4 ranks the fixations that overlap the speech window and labels each `gazeTarget` with
whatever `id` the fixation stream currently carries (a geometric/region placeholder until
Phase 5). When element resolution lands, utterances inherit named targets with no change to
the fusion logic.

## Capabilities

### New Capabilities
- `speech-capture`: push-to-talk speech recognition that yields recognized text, a confidence,
  and a precise capture window, using on-device recognition for privacy.
- `voice-activity`: mouth-aspect-ratio derived from lip landmarks, sampled per frame and
  reduced to `VoiceActivity` (`jawOpenMean`, `peak`) over a window — voice-activity and
  emphasis timing, never word content.
- `utterance-fusion`: fuse a speech window with the fixation stream and voice-activity into a
  ranked `Utterance` event (overlap-classified `gazeTargets`, `primaryTarget` heuristic).

### Modified Capabilities
<!-- None. No existing per-change specs; Phase 4 only adds producers for the already-defined
     Utterance / VoiceActivity types. -->

## Impact

- **GazeKit**: new MAR computation and utterance-fuser sources + unit tests (`swift test`,
  no Xcode). Stays platform-agnostic — no AVFoundation/Speech imports here.
- **apps/macOS**: new `SpeechRecognizer` (Speech + AVFoundation), MAR wiring off the existing
  `VisionFaceDetector` lip landmarks, `CalibrationViewModel` Run-mode integration, a Run-screen
  utterance readout, and `Info.plist` usage strings.
- **Dependencies / OS**: links `Speech.framework`; requires microphone + speech-recognition
  authorization. Within the macOS 14+ target already set.
- **Privacy**: on-device recognition; only the semantic `Utterance` leaves the perception
  layer — raw audio and frames do not.
