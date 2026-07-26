# Vergance

> **Voice can't point. Gaze can.** Look at something on screen, hold the talk button, and say
> "make **this** bigger" — Vergance resolves *this* to the element you were actually looking
> at. Today that lands as a structured event inside the app; the hand-off to a coding agent
> is Phase 6.

[![CI](https://github.com/Tatendaz/Vergance/actions/workflows/ci.yml/badge.svg)](https://github.com/Tatendaz/Vergance/actions/workflows/ci.yml)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%2014%2B%20%7C%20iOS%2017%2B-lightgrey.svg)](#prerequisites)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

**Status:** Phases 0–4 done, Phase 5(a) validated on-device — 48 green tests and a working
macOS app (webcam probe, 9-point calibration, fixations, voice fusion, named element targets).
The agent hand-off, the iPhone sensor and the heatmap are still ahead. [`ROADMAP.md`](ROADMAP.md)
is the source of truth — full spec, architecture, calibration math, event schema, phased plan.

---

## Overview

Vergance is a desktop tool where the camera watches your eyes and mouth. You look at a UI
element, say a command, and Vergance emits a small, semantic event — *"the user looked at
`cta-primary` for 620 ms while saying 'make this bigger'"* — that an agent like Claude can
act on. **Raw camera frames never leave the device; only semantic events do.**

Two product surfaces fall out of the same capture layer:

- **Live pointer** — gaze + voice → a resolved intent event, in real time (the flagship
  interaction). Today those events land in the app; handing them to an agent, as a Claude Code
  skill (`/vergance`) that streams gaze-resolved intent into your session, is **Phase 6**.
- **Post-hoc heatmap** — record a session and analyse where attention went (UX research).
  **Phase 8**: the `session_summary` event type exists, the aggregation and the viz don't.

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

- **Sensor-agnostic core.** Every sensor collapses to the same `GazeSample`, so backends are
  interchangeable by design. One exists today — the macOS webcam; the iPhone is Phase 7.
- **Calibration** — 9-point red-dot routine, quadratic least-squares with ridge regularization,
  reporting RMS error in pixels so the agent knows how far to trust a spatial claim.
- **One Euro filter → fixation detection** — adaptive smoothing (low latency on saccades, heavy
  smoothing on fixations) feeding a dwell / dispersion detector, not a fixed EMA.
- **Voice fusion** — hold-to-talk speech plus lip-based voice-activity, fused with the gaze
  held during the hold, into an `utterance` carrying a ranked `primaryTarget`.
- **Element resolution** — a fixation resolves to a *named* element (`cta-primary`, …) on
  Vergance's own canvas. Browser-DOM and Accessibility-API surfaces are staged after it.
- **Portable event schema** — debounced, element-resolved `Codable` events
  (`session_start`, `fixation`, `utterance`, `session_summary`) rather than raw 60 Hz samples.
  These are the types the Phase 6 hand-off to a coding agent will carry; today they stay in-process.
- **Drift handling** — a large head-pose delta from calibration prompts a recalibration.

*No screenshots yet — for a tool about looking at things, that's a real gap; capturing the live
overlay and calibration UI is part of Phase 9 (Polish), which covers docs.*

## Architecture

Three components around **one sensor-agnostic core**, because every sensor collapses to the
same `GazeSample`.

- **GazeKit** (`Sources/GazeKit/`, tests in `Tests/GazeKitTests/`) — shared, platform-agnostic
  Swift package holding everything in Features above, from the `GazeSensor` protocol to the
  event schema. Builds and unit-tests with `swift test`, no Xcode project.
- **Vergance for macOS** (`apps/macOS/`) — the app that exists today: SwiftUI, an
  AVFoundation + Vision webcam sensor, the calibration and overlay UI, `SFSpeechRecognizer`.
- **Vergance Companion (iOS)** (`apps/iOS/`) — **Phase 7, not wired yet.** Planned: an ARKit
  TrueDepth sensor streaming `GazeSample`s to the Mac over Network.framework + Bonjour, with
  the Mac as receiver. The current target is a placeholder screen.

`Package.swift` declares the core package, `project.yml` is the XcodeGen spec for both app
targets, `openspec/` holds the change workflow. The component diagram, the signal table, the
full pipeline and the calibration math are in [`ROADMAP.md`](ROADMAP.md) §2–§3.

## Getting started

### Prerequisites

- **macOS 14+.** Not just a runtime floor — `Package.swift` declares it as the package
  platform, so `swift build` fails on anything older.
- **Swift 5.9+** (`swift-tools-version: 5.9`; check with `swift --version`). Ships with
  Xcode 15+; on a clean Mac install at least `xcode-select --install`. "No Xcode project"
  below means no `.xcodeproj` — you still need a toolchain.
- **For the app targets only:** Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
- The macOS app asks for **camera, microphone and speech-recognition** permission on first run.

### Core package (no Xcode project)

```sh
git clone https://github.com/Tatendaz/Vergance.git
cd Vergance
swift build
swift test
```

### Apps (Xcode)

The macOS and iOS app targets are generated from `project.yml` with XcodeGen — via Homebrew,
or via [Mint](https://github.com/yonaskolb/Mint) or a prebuilt release if you don't have it:

```sh
brew install xcodegen        # or: mint install yonaskolb/XcodeGen
xcodegen generate
open Vergance.xcodeproj
```

## Roadmap / status

Deliverables and rationale per phase are in [`ROADMAP.md`](ROADMAP.md) §5:

| Phase | Status |
|---|---|
| **0–3** — foundations · webcam probe · calibration + mapping · fixation + events | ✅ done |
| **4** — voice fusion (`SFSpeechRecognizer` + lip-MAR → `utterance`) | ✅ done, validated on-device |
| **5** — element resolution, staged surfaces | 🚧 (a) own canvas ✅ done · (b) DOM + (c) AX pending |
| **6** — Claude integration: a `/vergance` Claude Code skill | planned |
| **7** — iPhone TrueDepth: iOS companion, ARKit sensor, Bonjour stream | planned |
| **8** — heatmap / UX mode: `session_summary` aggregation + scanpath viz | planned |
| **9** — polish: calibration profiles, recalibration UX, privacy pass, packaging | planned |

## Contributing

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a PR. It covers the OpenSpec
propose → apply → sync → archive workflow and when it's required, the `docs/features/` entry
every PR must carry, the rule that `Sources/GazeKit` may import only Foundation (CI enforces it
by compiling the core on Linux), and the required checks. You need no Apple ID, certificate or
secrets — fork PRs build fine.

Two things that catch people out: non-trivial changes go through the OpenSpec workflow
(`openspec/`) before implementation, and `docs/summaries/` is gitignored and local-only, so
only the `docs/features/` entry is required.

Found a security or privacy issue? See [`SECURITY.md`](SECURITY.md) — please don't open a
public issue for it.

## License

[Apache-2.0](LICENSE) © 2026 Tatenda Zhou. Free for everyone including commercial use, with an
explicit patent grant covering the gaze / calibration methods.
