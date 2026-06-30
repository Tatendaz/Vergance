# Feature: Phase 4 — voice fusion (utterance event stream)

**Branch:** worktree-phase-4-voice-fusion
**Date:** 2026-06-29

## Summary
Fuses recognized speech (push-to-talk) with the gaze the user held while speaking into the
Claude-facing `utterance` event — the deixis-resolving core object ("make **this** bigger").
Audio supplies the words; the lips (mouth-aspect-ratio) supply timing/emphasis, never lipreading.

## What changed
- **GazeKit** (platform-agnostic, +14 tests → 35 total green):
  - `VoiceActivity+Window.swift` — `MouthSample` (timestamped openness, lifts off `GazeSample`)
    + the `VoiceActivity(from:in:)` window reduction (mean + peak; empty window → zeros). Reuses
    the existing `GazeFeatures.mouthAspectRatio`.
  - `UtteranceFuser.swift` — `SpeechResult`, the `Overlap` classifier
    (`during`/`leading`/`trailing` with lead/trail margins), score ranking (class weight + dwell),
    the `primaryTarget` margin heuristic, and `Utterance` assembly.
- **apps/macOS:**
  - `SpeechRecognizer.swift` — `SFSpeechRecognizer` + `AVAudioEngine`, on-device only
    (`requiresOnDeviceRecognition`), microphone + speech authorization, one final transcription
    per hold; a silent hold resolves to "nothing recognized" rather than an error.
  - `CalibrationViewModel` — Run-mode ring buffers (recent fixations + MAR samples), push-to-talk
    (`startTalking`/`stopTalking`) that stamps the capture window from the **shared gaze clock**
    (`sample.t`), flushes the in-progress fixation on release, fuses, and publishes the
    `Utterance` + speech state.
  - `GazeCursorView` — a hold-to-talk control plus an utterance readout (recognized text,
    resolved/ambiguous target, ranked alternatives, jaw-peak + speech confidence) and
    authorization / no-speech states.

## Notes
- MAR was already computed in GazeKit and flows through every `GazeSample` as `mouth.openness`,
  so it was reused rather than duplicated — the voice-activity work was just the sample type +
  window reduction.
- The speech window uses the same clock as fixations and MAR samples (`GazeSample.t`, the
  capture-frame PTS); this is required for correct overlap classification.
- Named element resolution is Phase 5. Gaze targets carry geometric **3×3 region placeholder ids**
  (`r1c1`, …) for now and will inherit named ids with no change to the fusion logic.
- The PTT control is a hold-to-talk button (simpler and more robust in SwiftUI) rather than the
  keyboard-hold originally sketched.
- Verification: `swift test` 35/35 green; the macOS app `BUILD SUCCEEDED` via headless
  `xcodebuild` (Xcode 26.5). **Manual on-device validation (camera + mic) is still pending** — a
  real Run-mode trial: look at a region, hold-talk-release a phrase, confirm the `utterance` text,
  sensible primary/alternatives, and a non-zero jaw peak.
