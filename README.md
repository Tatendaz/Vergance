# Vergance

> **Gaze + voice as a multimodal input layer.** Look at something on screen, speak, and your
> intent — resolved to *what you were looking at* — is delivered to Claude. Gaze supplies the
> deixis ("make **this** bigger") that voice alone can't.

[![CI](https://github.com/Tatendaz/Vergance/actions/workflows/ci.yml/badge.svg)](https://github.com/Tatendaz/Vergance/actions/workflows/ci.yml)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%2014%2B%20%7C%20iOS%2017%2B-lightgrey.svg)](#tech-stack)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

**Status:** pre-alpha / scaffolding. [`ROADMAP.md`](ROADMAP.md) is the source of truth — it
holds the full spec, architecture, event schema, and the phased plan. This README is the
overview.

---

## Overview

Vergance is a desktop tool where the camera watches your eyes and mouth. You look at a UI
element, say a command, and Vergance emits a small, semantic event — *"the user looked at
`cta-primary` for 620 ms while saying 'make this bigger'"* — that an agent like Claude can
act on. **Raw camera frames never leave the device; only semantic events do.**

Two product surfaces fall out of the same capture layer:

- **Live pointer** — gaze + voice → Claude, in real time (the flagship interaction). Delivered
  as a Claude Code skill (`/vergance`) that starts capture and streams gaze-resolved intent
  into your agent session, where it edits project files.
- **Post-hoc heatmap** — record a session and analyse where attention went (UX research).

### Honest accuracy bar

- **Webcam (v1):** region-level. Reliable 2×2 quadrant; 3×3 with a still head and good light.
  Enough to drive the interaction, not to distinguish adjacent buttons.
- **iPhone TrueDepth (v2):** materially better — real gaze vectors + depth.

### Non-goals (v1)

- **Silent lipreading** — visual speech recognition is unreliable. Vergance uses
  *audio-for-words* (speech recognizer) and *lips-for-timing* (mouth openness as
  voice-activity / emphasis).
- **Pixel-precise gaze** — region- and element-level is the target.
- **Cloud video** — on-device only.

## Features

- **Sensor-agnostic core.** Every sensor collapses to the same `GazeSample`, so the webcam and
  the iPhone are interchangeable and can run side-by-side.
- **Calibration** — 9-point red-dot routine, quadratic least-squares with ridge
  regularization, reporting RMS error in pixels so the agent knows how much to trust spatial
  claims.
- **One Euro filter** — adaptive smoothing (low latency on saccades, heavy smoothing on
  fixations) instead of a fixed EMA.
- **Fixation detection** — dwell / dispersion detector that turns the gaze stream into
  discrete fixations.
- **Element resolution** — staged surfaces: own canvas → browser DOM → Accessibility API.
- **Claude-facing event schema** — debounced, element-resolved `Codable` events
  (`session_start`, `fixation`, `utterance`, `session_summary`) rather than raw 60 Hz samples.
- **Drift handling** — head pose is captured into the feature vector; a large pose delta from
  the calibration baseline prompts a recalibration.

## Architecture

Three components around **one sensor-agnostic core**. Because every sensor collapses to the
same `GazeSample`, the webcam and the iPhone are interchangeable and can run side-by-side.

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  Vergance Companion      │     │  Vergance for macOS      │
│  (iOS)                   │     │  (the app)               │
│                          │     │                          │
│  ARKit ARFaceAnchor      │     │  AVFoundation + Vision   │
│  → TrueDepthSensor       │     │  → WebcamSensor          │
│        │ GazeSample      │     │        │ GazeSample      │
│        └──── Network ─────────▶│  receiver               │
└─────────────────────────┘     │        ▼                 │
                                 │  ┌───────────────────┐   │
        both emit the same  ───▶ │  │     GazeKit       │   │
        GazeSample stream        │  │  (shared core)    │   │
                                 │  └───────────────────┘   │
                                 └─────────────────────────┘
```

- **GazeKit** — shared, platform-agnostic Swift package: the data model, the `GazeSensor`
  protocol, calibration (quadratic ridge regression), the One Euro filter, the fixation
  detector, element mapping, and the Claude-facing event schema. Builds and unit-tests with
  `swift test`, no Xcode.
- **Vergance for macOS** — webcam sensor (AVFoundation + Vision), red-dot calibration UI, live
  landmark / gaze overlay, and the receiver for the phone stream.
- **Vergance Companion (iOS)** — ARKit TrueDepth sensor; streams `GazeSample`s to the Mac over
  Network.framework + Bonjour.

| Signal | Webcam (macOS / Vision) | TrueDepth (iOS / ARKit) |
|---|---|---|
| Gaze | pupil center relative to eye corners, per eye | `lookAtPoint` + per-eye transforms |
| Head pose | yaw / pitch / roll from `VNFaceObservation` | face-anchor transform |
| Mouth | mouth-aspect-ratio from lip-contour landmarks | `jawOpen` blendshape |
| Depth | none | yes |
| Speech | `SFSpeechRecognizer` | `SFSpeechRecognizer` |

### Pipeline

```
capture (sensor)
  → feature vector  [per-eye gaze features, head pose]
  → calibration regression → (sx, sy) screen point
  → One Euro filter (adaptive smoothing)
  → fixation detector (dwell / dispersion)
  → element resolution (own canvas → browser DOM → Accessibility API)
  → fuse with speech + mouth voice-activity
  → semantic events → local agent (Claude Code) edits project files
```

See [`ROADMAP.md`](ROADMAP.md) for the calibration math, the full event schema, and design
rationale.

## Tech stack

- **Language:** Swift 5.9
- **Core:** Swift Package Manager library (`GazeKit`), platform-agnostic, fully unit-tested
- **macOS:** AVFoundation + Vision, SwiftUI; macOS 14+
- **iOS:** ARKit (TrueDepth), Network.framework + Bonjour; iOS 17+
- **Speech:** `SFSpeechRecognizer`
- **App project generation:** [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`)
- **CI:** GitHub Actions — `swift build` + `swift test` on a macOS runner

## Getting started

### Core package (no Xcode)

`GazeKit` builds and tests on its own:

```sh
swift build
swift test
```

### Apps (Xcode)

The macOS and iOS app targets are generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open Vergance.xcodeproj
```

## Project structure

```
.
├── Package.swift            # GazeKit Swift package manifest
├── project.yml              # XcodeGen spec for the macOS + iOS app targets
├── Sources/GazeKit/         # shared core: GazeSample, GazeSensor, calibration,
│                            #   One Euro filter, fixation detector, ElementMap, Events
├── Tests/GazeKitTests/      # unit tests for the core
├── apps/macOS/              # webcam sensor, calibration UI, overlays, network receiver
├── apps/iOS/                # Vergance Companion (ARKit TrueDepth)
├── docs/features/           # per-feature change notes
├── openspec/                # OpenSpec change workflow
├── ROADMAP.md               # living spec + phased plan (source of truth)
└── .github/workflows/       # CI + PR gate
```

## Roadmap / status

GazeKit (Phase 0) builds with green unit tests; the macOS webcam probe, calibration, and
fixation work are in active development (see [`docs/features/`](docs/features)). The phased
plan, from [`ROADMAP.md`](ROADMAP.md):

| Phase | Title | Deliverable |
|---|---|---|
| **0** | Foundations | Repo, `GazeKit` package, CI, `GazeSample` / `GazeSensor`, event-schema types, unit tests — ✅ done |
| **1** | Webcam probe | macOS app: live webcam + Vision landmark overlay + head-pose readout |
| **2** | Calibration + mapping | 9-point red-dot UI, ridge regression, One Euro, live RMS-error readout |
| **3** | Fixation + events | Dwell / dispersion detector → `session_start` + `fixation` emit |
| **4** | Voice fusion | `SFSpeechRecognizer` + lip-MAR voice-activity → `utterance` events |
| **5** | Element resolution | Staged surfaces (own canvas → browser DOM → Accessibility API) |
| **6** | Claude integration + skill | Ship a Vergance Claude Code skill (`/vergance`) |
| **7** | iPhone TrueDepth | iOS companion, ARKit sensor, Bonjour stream, dual-sensor live |
| **8** | Heatmap / UX mode | `session_summary` aggregation + heatmap & scanpath viz |
| **9** | Polish | Calibration profiles, recalibration UX, privacy pass, packaging |

Non-trivial changes go through the OpenSpec workflow (`openspec/`) before implementation.

## License

[Apache-2.0](LICENSE) © 2026 Tatenda Zhou. Free for everyone including commercial use, with an
explicit patent grant covering the gaze / calibration methods.
