# Vergance — Roadmap & Spec

> **Gaze + voice as a multimodal input layer.** Look at something on screen, speak, and your
> intent — resolved to *what you were looking at* — is delivered to Claude.
> Gaze supplies the deixis ("make **this** bigger") that voice alone can't.

**Status:** pre-alpha / scaffolding. This document is the living spec. Non-trivial changes
go through the OpenSpec workflow (`openspec/`) before implementation.

---

## 1. Concept

A desktop tool where the camera watches your eyes and mouth. You look at a UI element,
say a command, and Vergance emits a small, semantic event — *"the user looked at
`cta-primary` for 620ms while saying 'make this bigger'"* — that Claude can act on.
Two product surfaces fall out of the same capture layer:

- **Live pointer** — gaze + voice → Claude, in real time (the flagship interaction).
- **Post-hoc heatmap** — record a session, analyse where attention went (UX research).

Both ship — see the v1-mode decision in §6. The live-pointer surface is delivered as a
**Vergance skill for Claude Code** (`/vergance`): invoke it to start gaze+voice capture and
feed gaze-resolved intent straight into your Claude Code session, where the agent edits files.

### Honest accuracy bar
- **Webcam (v1):** region-level. Reliable 2×2 quadrant; 3×3 with a still head and good
  light. Enough to drive the interaction, not enough to distinguish adjacent buttons.
- **iPhone TrueDepth (v2):** materially better — real gaze vectors + depth.

### Non-goals (v1)
- **Silent lipreading.** Visual speech recognition is unreliable. We use
  *audio-for-words* (speech recognizer) and *lips-for-timing* (mouth openness as
  voice-activity + emphasis).
- **Pixel-precise gaze.** Region- and element-level is the target.
- **Cloud video.** Raw camera frames never leave the device; only semantic events do.

---

## 2. Architecture

Three components around **one sensor-agnostic core**. Because every sensor collapses to
the same `GazeSample`, the webcam and the iPhone are interchangeable and can run
side-by-side.

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

### Components
- **GazeKit** — shared Swift Package, platform-agnostic. Owns the data model, the
  `GazeSensor` protocol, calibration math, the One Euro filter, the fixation detector,
  and the Claude-facing event schema. Builds and unit-tests with `swift test`, no Xcode.
- **Vergance for macOS** — the main app. `WebcamSensor`, the red-dot calibration UI, the
  live debug overlay, the element-resolution layer, and the network receiver for the
  phone stream.
- **Vergance Companion (iOS)** — captures `ARFaceAnchor`, builds `GazeSample`s, streams
  them to the Mac over Network.framework + Bonjour.

### The sensor abstraction
```swift
protocol GazeSensor: AnyObject {
    var samples: AsyncStream<GazeSample> { get }
    func start() async throws
    func stop()
}

struct GazeSample {
    let t: TimeInterval            // monotonic capture time
    let gazeFeatures: [Double]     // sensor-specific raw features (pre-calibration)
    let headPose: HeadPose         // yaw / pitch / roll
    let mouth: MouthSignal         // openness + emphasis (blendshape or MAR proxy)
    let confidence: Double
}
```

| Signal | Webcam (macOS / Vision) | TrueDepth (iOS / ARKit) |
|---|---|---|
| Gaze | pupil center relative to eye corners, per eye | `lookAtPoint` + per-eye transforms |
| Head pose | `yaw`/`pitch`/`roll` from `VNFaceObservation` | face-anchor transform |
| Mouth | mouth-aspect-ratio from lip-contour landmarks | `jawOpen` / mouth blendshapes |
| Depth | none | yes |
| Speech | `SFSpeechRecognizer` | `SFSpeechRecognizer` |

---

## 3. Pipeline

```
capture (sensor)
  → feature vector  [per-eye gaze features, head pose]
  → calibration regression → (sx, sy) screen point
  → One Euro filter (adaptive smoothing)
  → fixation detector (dwell / dispersion)
  → element resolution (staged: own canvas → browser DOM → Accessibility API)
  → fuse with speech (SFSpeechRecognizer) + mouth voice-activity
  → semantic events → local agent (Claude Code) edits project files
```

### Calibration
- **Sequence:** 9 points (corners + edge midpoints + center). 5 works; 9 is steadier.
- **Sampling:** ~30 frames per dot, discard the first ~10 (saccade settling), take the
  **median** of the rest (kills blink/tracking-loss outliers).
- **Model:** quadratic least squares with feature row
  `φ(g) = [1, gx, gy, gx·gy, gx², gy²]`, **ridge-regularized** (`λI` — 9 points overfit
  under OLS). Center/scale features first (the squared terms are tiny → ill-conditioned).
- **Runtime smoothing:** One Euro filter, not a fixed EMA (low latency on saccades, heavy
  smoothing on fixations).
- **Drift:** assume a still head; treat a large head-pose delta from the calibration
  baseline as a "recalibrate" prompt. Head pose is captured into the feature vector so a
  later version can compensate in-model without re-architecting.
- **Quality metric:** report calibration RMS error in pixels; surface it to Claude so it
  knows how much to trust spatial claims.

Implemented in `GazeKit`: `CalibrationFitter` / `CalibrationModel` (ridge quadratic),
`OneEuroFilter`, `FixationDetector`, `ElementMap` — all unit-tested.

---

## 4. Claude-facing event schema

Claude never sees raw 60 Hz samples — the app does the perception and emits debounced,
**element-resolved** events.

- `session_start` — screen size, coord system, calibration quality (`rmsErrorPx`).
- `fixation` — gaze dwelling on a region (>150 ms within a small radius), resolved to a
  target element (`id`, `role`, `label`) + confidence.
- `utterance` — **the core object.** Recognized text + a *ranked* list of `gazeTargets`
  with dwell/overlap/confidence + a `primaryTarget` best-guess + `voiceActivity`
  (jaw-openness stats). Ships alternatives so Claude can disambiguate when the top two
  are close.
- `session_summary` — per-region fixation counts, total dwell, **first-fixation time**,
  and scanpath (the heatmap / UX-analysis reduction).

All four are implemented as `Codable` types in `GazeKit/Events.swift`.

---

## 5. Phased roadmap

| Phase | Title | Deliverable | Why |
|---|---|---|---|
| **0** | Foundations | Repo, `GazeKit` package, CI, `GazeSample`/`GazeSensor`, event-schema types, unit tests | ✅ done — builds + 8 tests green |
| **1** | Webcam probe | macOS app: live webcam + Vision landmark overlay + head-pose readout | **De-risks the whole approach** — is pupil tracking stable enough? |
| **2** | Calibration + mapping | 9-point red-dot UI, ridge regression, One Euro, live RMS-error readout | Produces the mapping everything downstream needs |
| **3** | Fixation + events | Dwell/dispersion detector → `session_start` + `fixation` emit | First real event stream |
| **4** | Voice fusion | `SFSpeechRecognizer` + lip-MAR voice-activity → `utterance` events | ✅ done — 35 tests green, app builds, voice→utterance validated on-device |
| **5** | Element resolution | Staged surfaces: (a) own canvas → (b) browser DOM → (c) Accessibility API; `primaryTarget` heuristic | 🚧 (a) own-canvas ✅ done — 46 tests green, named `cta-primary` targets validated on-device; (b) DOM + (c) AX pending |
| **6** | Claude integration + skill | Ship a **Vergance Claude Code skill** (`/vergance`) that starts gaze+voice capture and streams gaze-resolved utterances into the agent session, which edits project files | The payoff loop — and the natural home for "local agent edits files" |
| **7** | iPhone TrueDepth | iOS companion, ARKit sensor, Bonjour stream, dual-sensor live | The accuracy upgrade |
| **8** | Heatmap / UX mode | `session_summary` aggregation + heatmap & scanpath viz | Second product surface |
| **9** | Polish | Calibration profiles, recalibration UX, privacy pass, packaging, docs | Ship-ready |

---

## 6. Open questions

**✅ = decided**; **★ = newly surfaced**; the rest have a working default and can be
confirmed later.

| # | Question | Status / default |
|---|---|---|
| ✅ 1 | **License** | **Apache-2.0** — true open source (free incl. commercial, + patent grant) |
| ✅ 2 | **Name spelling** | **Vergance** (kept as typed; say the word for `Vergence`) |
| ✅ 3 | **v1 mode** | **Both** — shared capture layer, ship live pointer + heatmap |
| ✅ 4 | **Look surface** | **Staged: (1) own canvas → (2) browser DOM → (3) Accessibility API** |
| ✅ 5 | **Claude integration** | **Local agent edits files** (e.g. Claude Code) |
| ★ 6 | **How the Vergance skill feeds the agent** | A Claude Code skill (`/vergance`) is the chosen surface; under it — MCP server · Agent SDK · watched file — TBD (Phase 6) |
| 7 | **iPhone → Mac transport** | Network.framework + Bonjour (default) · MultipeerConnectivity · Continuity |
| 8 | **Speech trigger** | Push-to-talk (default, privacy-friendly) · always-listening · wake word |
| 9 | **Min OS / devices** | macOS 14+ · iOS 17+ + TrueDepth (A12+) — confirm |
| 10 | **Privacy posture** | On-device only; only semantic events leave the machine — confirm wording |
| 11 | **GitHub** — where to publish | **Public** (requested); Tatendaz personal vs Firesoftware2 org — TBD |
| 12 | **Bundle ID / org prefix** | `com.firesoftware.vergance` (default) |
| 13 | **Accessibility positioning** | Eye+voice control is a strong assistive-tech use case — in scope as a goal? |

---

## 7. License

**Apache-2.0** — true open source: free for everyone including commercial use, with an
explicit patent grant covering the gaze/calibration methods. Chosen over the
personal-vs-commercial restriction discussed earlier. (Switch to MIT to drop the patent
clause.) See [LICENSE](LICENSE).
