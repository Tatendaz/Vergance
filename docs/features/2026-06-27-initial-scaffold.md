# Feature: Initial project scaffold

**Branch:** main
**Date:** 2026-06-27

## Summary
Genesis commit for Vergance — a gaze + voice multimodal input layer that resolves spoken
intent to the on-screen element you were looking at and feeds it to a local Claude agent.

## Motivation
Establish the architecture and a verified core before building capture. Gaze supplies the
deixis ("make *this* bigger") that voice alone can't.

## What changed
- **GazeKit** SwiftPM package (platform-agnostic — builds and tests with no Xcode):
  - `GazeSample` / `GazeSensor` sensor abstraction (webcam + TrueDepth interchangeable)
  - `CalibrationFitter` / `CalibrationModel` — quadratic ridge regression
  - `OneEuroFilter` — adaptive gaze smoothing
  - `FixationDetector` — dispersion-threshold dwell detection
  - `ElementMap` — gaze → element hit-testing
  - Claude-facing event schema: `session_start` / `fixation` / `utterance` / `session_summary`
  - 8 unit tests, all passing
- macOS + iOS app scaffold generated from `project.yml` (XcodeGen)
- Apache-2.0 license, README, ROADMAP (spec + 10-phase plan), CLAUDE.md
- GitHub Actions CI (`swift build` + `swift test`)
- OpenSpec workflow (`openspec/`, `/opsx:` commands)

## Notes
Pre-alpha. Next: Phase 1 webcam probe (AVFoundation + Vision landmark overlay) to de-risk
pupil-tracking stability before calibration. A `/vergance` Claude Code skill is the planned
delivery surface for the live gaze+voice loop (ROADMAP §5, Phase 6).
