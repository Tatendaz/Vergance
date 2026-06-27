# Vergance

> Gaze + voice as a multimodal input layer. Look at something on screen, speak, and your
> intent — resolved to *what you were looking at* — is delivered to Claude. Gaze supplies
> the deixis ("make **this** bigger") that voice alone can't.

**Status:** pre-alpha. See [ROADMAP.md](ROADMAP.md) for the spec, architecture, and the
phased plan.

## Architecture

Three components around one sensor-agnostic core. Every sensor collapses to the same
`GazeSample`, so the webcam and the iPhone are interchangeable and can run side-by-side.

- **GazeKit** — shared, platform-agnostic Swift package: the data model, the `GazeSensor`
  protocol, calibration (quadratic ridge regression), the One Euro filter, the fixation
  detector, and the Claude-facing event schema. Builds and tests with no Xcode.
- **Vergance for macOS** — webcam sensor (AVFoundation + Vision), red-dot calibration UI,
  live overlay, and the receiver for the phone stream.
- **Vergance Companion (iOS)** — ARKit TrueDepth sensor, streams `GazeSample`s to the Mac.

| Signal | Webcam (macOS / Vision) | TrueDepth (iOS / ARKit) |
|---|---|---|
| Gaze | pupil center relative to eye corners | `lookAtPoint` + per-eye transforms |
| Head pose | `VNFaceObservation` yaw/pitch/roll | face-anchor transform |
| Mouth | mouth-aspect-ratio from lip landmarks | `jawOpen` blendshape |
| Depth | none | yes |

## Build

### Core package (no Xcode)

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

## License

[Apache-2.0](LICENSE) © 2026 Tatenda Zhou.
