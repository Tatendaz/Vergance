## 1. GazeKit — mouth-aspect-ratio (voice-activity)

- [x] 1.1 Add `MouthAspectRatio` (pure geometry): compute MAR = vertical lip separation ÷ mouth width from lip-contour points, plus a `(t, mar)` sample type
- [x] 1.2 Add window reduction `VoiceActivity(from:in:)` → `jawOpenMean` (mean) and `peak` (max) over samples within `[tStart, tEnd]`; empty window → zeros
- [x] 1.3 Tests: closed→~0, open→larger, distance-invariance (scale points), mean/peak reduction, empty-window zeros, gap frames ignored

## 2. GazeKit — utterance fusion

- [x] 2.1 Add `UtteranceFuser` with named constants (lead/trail margins, class weights, dwell weight, `primaryMargin`)
- [x] 2.2 Implement overlap classification of a fixation vs. the speech window → `during` / `leading` / `trailing` / excluded
- [x] 2.3 Implement ranking (classWeight + dwellWeight·dwell) and `primaryTarget` margin heuristic
- [x] 2.4 Assemble the `Utterance` (text, confidence, window, ranked `gazeTargets`, `primaryTarget`, `VoiceActivity`)
- [x] 2.5 Tests: during>leading>trailing ordering, dwell tiebreak, far fixation excluded, clear-winner sets primaryTarget, near-tie → nil, no-fixation → empty targets + text still emitted
- [x] 2.6 `swift build && swift test` green

## 3. macOS — speech capture

- [x] 3.1 Add `SpeechRecognizer`: `SFSpeechRecognizer` + `AVAudioEngine`, `requiresOnDeviceRecognition = true`; error if `supportsOnDeviceRecognition` is false
- [x] 3.2 Push-to-talk API: start on hold (stamp `tStart` from the shared monotonic capture clock), stop on release (stamp `tEnd`), return `text` + `speechConfidence` + window
- [x] 3.3 Authorization flow for microphone + speech recognition; denied → no capture, surfaced error
- [x] 3.4 No-speech window → no result (caller emits nothing)

## 4. macOS — MAR feed from Vision

- [x] 4.1 Extract lip-contour points from the existing `VisionFaceDetector` landmarks and feed `MouthAspectRatio` per frame
- [x] 4.2 Push `(t, mar)` samples (stamped on the shared capture clock) into a bounded ring buffer in `CalibrationViewModel`

## 5. macOS — Run-mode integration & UI

- [x] 5.1 Bounded ring buffers for recent fixations + MAR samples in Run mode
- [x] 5.2 Wire a PTT control (hold-to-talk button for v1); on release, slice buffers to the window, call `UtteranceFuser`, append `Utterance` to the event log
- [x] 5.3 Run-screen readout: recognized text, `primaryTarget` (or "ambiguous"), ranked alternatives, jaw-open peak; show authorization/no-speech states

## 6. Permissions & project config

- [x] 6.1 Add `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription` to the macOS app Info.plist / `project.yml` (already present in the scaffold)
- [x] 6.2 Link `Speech.framework`; `xcodegen generate` and confirm the app target builds (BUILD SUCCEEDED, Xcode 26.5; Speech links implicitly via `import`)

## 7. Docs & verification

- [x] 7.1 Manual Run-mode validation: look at a region, hold-talk-release a phrase → `Utterance` with correct text, sensible primary/alternatives, non-zero jaw-open peak
- [x] 7.2 Write `docs/features/<date>-phase-4-voice-fusion.md` and a matching `docs/summaries/` entry
- [x] 7.3 Update `ROADMAP.md` Phase 4 row to done
