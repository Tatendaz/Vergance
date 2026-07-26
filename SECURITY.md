# Security Policy

Vergance watches your face and listens to your voice. That makes its security and
privacy properties part of the product, not a footnote — and it means this repo
needs a disclosure channel. This is it.

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Report it privately through GitHub's
[**Report a vulnerability**](https://github.com/Tatendaz/Vergance/security/advisories/new)
form (Security → Advisories on this repository). That creates a private advisory
visible only to you as the reporter and to this repository's authorized
security personnel (administrators and anyone with the security-manager role).

If private advisories are unavailable to you for any reason, do **not** put the
details anywhere public. Open an issue containing only the words *"security
report, please open a private channel"* — no description, no reproduction, no
affected version — or contact the maintainer through the address on the
[@Tatendaz GitHub profile](https://github.com/Tatendaz). A private advisory or
another private channel will be opened for you, and the details go there.

If you are the maintainer reading this: a dedicated, monitored security address
published here would be better than the profile-contact round trip. Add one and
replace this paragraph.

**What to include:** what you found, how to reproduce it, what an attacker gains,
and the version or commit you tested. A proof of concept helps enormously.
Please do not include anyone's real camera or audio capture in a report; a
description or synthetic data is enough.

**What to expect:** an acknowledgement within a few days, and an assessment of
severity and a fix plan once the report has been reproduced. Vergance is a
pre-1.0 personal project with a single maintainer, so please calibrate your
expectations for response speed accordingly — but reports will be read and taken
seriously. You will be credited in the advisory unless you'd rather not be.

Please give a reasonable window for a fix before disclosing publicly.

## Supported versions

Vergance is **pre-1.0**. Tagged releases (v0.1.0) are point-in-time source
snapshots with no maintenance branches; only the `main` branch is supported, and
fixes land there. Do not run this on data or a machine you care about yet.

## The privacy claim, stated precisely

`README.md` and `ROADMAP.md` both make a specific promise:

> **Raw camera frames never leave the device; only semantic events do.**

That is the property most worth attacking, so here is exactly what it does and
does not cover as of today:

**What the app has access to.** The macOS target declares these entitlements in
[`project.yml`](project.yml), and they end up in the generated
`apps/macOS/Vergance.entitlements`:

| Entitlement | Why |
|---|---|
| `com.apple.security.app-sandbox` | The app runs sandboxed. |
| `com.apple.security.device.camera` | Webcam capture for gaze and mouth tracking. |
| `com.apple.security.device.audio-input` | Microphone capture for speech. |
| `com.apple.security.network.client` | Reserved for the Phase 7 iPhone → Mac stream. |
| `com.apple.security.network.server` | Reserved for the Phase 7 iPhone → Mac stream. |

Plus the usage descriptions `NSCameraUsageDescription`,
`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` and (on
iOS) `NSLocalNetworkUsageDescription`.

**The network entitlements are the honest wart.** They are declared for a
capability — streaming `GazeSample`s from the iPhone companion to the Mac over
the local network — that **is not built yet** (Phase 7). Until it is, the app
holds network permissions it does not use. Grant them the scrutiny that deserves,
and treat any *outbound* traffic from Vergance today as a bug worth reporting.

**Where the sensitive processing happens.**

- Camera frames are handled in `apps/macOS/CameraSession.swift` and
  `apps/macOS/WebcamSensor.swift`, turned into landmarks by
  `apps/macOS/VisionFaceDetector.swift` (Apple's Vision framework, on-device),
  and then **discarded**. No frame is written to disk and none is transmitted.
- Speech is handled in `apps/macOS/SpeechRecognizer.swift`. It sets
  `requiresOnDeviceRecognition = true` and **throws rather than falling back to a
  network request** if on-device recognition is unavailable for the current
  locale. That is deliberate: audio must not leave the machine to get
  transcribed. A change that weakens that flag is a security regression, not a
  feature.
- Capture is **push-to-talk**, not always-listening — the microphone runs only
  while the Talk control is held.
- What crosses the boundary out of the capture layer are the `Codable` events in
  `Sources/GazeKit/Events.swift` (`session_start`, `fixation`, `utterance`,
  `session_summary`). An `utterance` **does carry recognized text** — the words
  you spoke. That is the point of the product, but it means the event stream is
  sensitive, and anything that consumes it (Phase 6's Claude Code skill) inherits
  that sensitivity.

**Not yet assessed.** There has been no formal threat model, no audit, and no
review of the Phase 7 local-network transport (which does not exist yet).
Treat this section as a statement of design intent that reviewers are invited to
falsify, not as a certification.

## Things worth reporting

- Any path by which a raw frame, an audio buffer, or a captured image leaves the
  process — written to disk, logged, or transmitted.
- Speech being transcribed off-device (i.e. `requiresOnDeviceRecognition` being
  bypassed or defeated).
- Recognized text or event data leaking into logs, crash reports, or telemetry.
- Anything that lets another local process read the event stream, or drive
  capture without the user's knowledge.
- Weaknesses in the repo's own supply chain: an unpinned or compromised GitHub
  Action, a workflow that can be made to run untrusted code with elevated
  permissions, or a way to exfiltrate `GITHUB_TOKEN`. (Workflows are pinned to
  commit SHAs and hold `permissions: contents: read`; both are deliberate.)

## Out of scope

- The absence of code signing or notarisation in CI. That is intentional — the
  PR path uses `CODE_SIGNING_ALLOWED=NO` specifically so that fork pull requests
  build without any secrets. There are no signing secrets in this repository to
  compromise.
- Missing features from unimplemented roadmap phases.
- Findings that require an attacker to already have physical access to, or code
  execution on, an unlocked machine — at that point the webcam is theirs anyway.
- Reports generated wholesale by an automated scanner with no analysis of whether
  the finding is reachable in this codebase.
