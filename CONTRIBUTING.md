# Contributing to Vergance

Thanks for wanting to help. Vergance has a slightly unusual process — it is
**spec-driven** (changes are proposed before they are written) and its core is
**deliberately platform-agnostic**. Both of those are now enforced by CI, so
this page exists to make sure you find out about them *before* a red check tells
you, rather than after.

Read [`ROADMAP.md`](ROADMAP.md) first if you want to know *what* to build — it is
the source of truth for the spec, the event schema, and the phased plan. This
page is about *how* to land it.

---

## 1. Setup and tests

**Prerequisites:** a Swift 5.9+ toolchain. That's it for the core.

**There is no install step.** `Package.swift` declares **zero external
dependencies**, so there is nothing to fetch — no `npm ci`, no `pod install`, no
`swift package resolve` needed. Clone and build:

```sh
swift build
swift test          # 48 tests today, ~0.01s
```

That covers `Sources/GazeKit/` and `Tests/GazeKitTests/` — the whole shared core,
**with no Xcode required**.

### The apps

The macOS and iOS app targets are **not** part of the Swift package. They are
generated from [`project.yml`](project.yml) by
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open Vergance.xcodeproj
```

`xcodegen generate` is **mandatory**, not a convenience: `project.yml` also
generates `apps/macOS/Info.plist`, `apps/iOS/Info.plist` and
`apps/macOS/Vergance.entitlements`, all of which are `.gitignore`d. A fresh clone
does not contain them, so `xcodebuild` cannot work until you have run it.

To reproduce exactly what CI does to the apps (no Xcode UI, no signing):

```sh
xcodebuild build -project Vergance.xcodeproj -scheme Vergance \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

xcodebuild build -project Vergance.xcodeproj -scheme VerganceCompanion \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

---

## 2. Branch names

Use `<type>/<slug>`, where type is one of `feat` / `fix` / `docs` / `chore` /
`refactor`:

```
feat/phase-6-claude-skill
fix/calibration-drift-threshold
docs/expand-readme
```

> **Editing a file through GitHub's web UI creates a branch called `patch-1`.**
> Please don't. Create a properly-named branch instead — the whole repo's
> conventions (feature-doc filenames, PR titles, the changelog you leave behind)
> key off a meaningful slug, and `patch-1` tells a future reader nothing.

The slug is what you reuse for your `docs/features/` filename, so pick it once
and keep it consistent.

---

## 3. What your PR must include

**Every PR must add or update a file matching `docs/features/*.md`.** This is a
hard CI gate (`PR Gate / Docs gate`) and it is the single most common reason a
first-time PR goes red. Worked example, for a branch named
`feat/add-blink-detection`:

```
docs/features/2026-07-25-add-blink-detection.md
```

**`docs/summaries/` is NOT required and does not exist in this repo.** It is
`.gitignore`d — session prompt-logs stay local for privacy. Don't go looking for
the directory and don't try to add one; only `docs/features/` is checked.

### What goes in a feature doc

Match the existing files in [`docs/features/`](docs/features). The shape is:

```markdown
# Feature: <title>

**Branch:** feat/add-blink-detection
**Date:** 2026-07-25

## Summary
What this does and why it matters, in a short paragraph.

## What changed
- **GazeKit** (platform-agnostic): the core changes, and the test delta.
- **apps/macOS:** the app-side wiring.

## Notes
Tradeoffs, things deliberately out of scope, follow-ups.
- Verification: `swift test` N/N green; the macOS app `BUILD SUCCEEDED` via
  headless `xcodebuild`; validated on-device by <how>.
```

That last **Verification** line is a convention, not decoration — CI can only
prove the app *compiles* (see §4), so the feature doc is where a human records
that they actually pointed a camera at their face and watched it work.

### If it is a non-trivial change: the OpenSpec workflow

Vergance is spec-driven. **Non-trivial changes get proposed before they get
written**, through [OpenSpec](https://github.com/Fission-AI/OpenSpec)
(`openspec/config.yaml` declares `schema: spec-driven`). Until now this lived
only in agent-facing files, which made it undiscoverable — hence this section.

**When it is required:** anything that adds or changes a *capability* — new
behaviour in `GazeKit`, a new event type or field, a change to how gaze or speech
is interpreted, anything that moves a `ROADMAP.md` phase forward.

**When you can skip it:** a genuinely small, self-contained change with no
capability delta — a typo, a doc fix, a one-line bug fix with a regression test,
a CI/tooling chore. If you are unsure, open an issue and ask before you write
code; that is cheaper than a rejected PR.

The lifecycle, driven by the `/opsx:` slash commands in `.claude/commands/opsx/`
(or by hand — the commands only automate file-shuffling you could do yourself):

| Step | Command | What it does |
|---|---|---|
| 1 | `/opsx:propose <kebab-name>` | Creates `openspec/changes/<kebab-name>/` and generates `proposal.md` → `design.md` → `tasks.md`. |
| 2 | `/opsx:apply` | Implements `tasks.md`, ticking `- [ ]` → `- [x]` as you go. |
| 3 | `/opsx:sync` | Merges the change's delta specs into `openspec/specs/<capability>/spec.md`. |
| 4 | `/opsx:archive` | Moves the change to `openspec/changes/archive/<YYYY-MM-DD>-<name>/`. |

There is also `/opsx:explore` for thinking something through before proposing it.
It deliberately never writes implementation code.

**Validate before you push:**

```sh
npm install -g @fission-ai/openspec      # or: npx @fission-ai/openspec …
openspec validate <change-name> --strict
```

It must print `Change '<name>' is valid` and exit 0. Nothing in CI runs this
today — it is a review-time expectation, so please don't skip it.

**Document shapes**, matching the real files under `openspec/`:

- **`proposal.md`** — `## Why`, `## What Changes`, `## Capabilities` (with
  `### New Capabilities` / `### Modified Capabilities`), `## Impact`. State an
  explicit scope boundary and whether the change is breaking.
- **`design.md`** — `## Context` (including a *Constraints* list drawn from
  `CLAUDE.md` / `ROADMAP.md`), `## Goals / Non-Goals`, `## Decisions` — numbered,
  each recording the alternative you rejected and why.
- **`tasks.md`** — numbered sections of `- [ ]` items. The house convention is:
  §1 headless `GazeKit` work verifiable by `swift test`; §2 app work marked
  *"(needs Xcode/GUI; CHECKPOINT before starting)"*; §3 *"Docs, spec sync & gate"*.
- **Delta specs** (`openspec/changes/<name>/specs/<capability>/spec.md`) —
  `## ADDED Requirements` / `## MODIFIED Requirements`, then
  `### Requirement: <name>` phrased with **SHALL**, each followed by one or more
  `#### Scenario: <name>` written as `- **WHEN** … / - **THEN** …`.

### Also update `ROADMAP.md`

`ROADMAP.md` is the source of truth. If your change advances a phase, update its
row in the phase table as part of the same PR.

---

## 4. Does my change need a test?

**If it touches `Sources/GazeKit/`, yes — always.** The core is pure logic with
no Apple-framework dependency, so there is never a good reason for a change there
to be untestable. Write the test first; `Tests/GazeKitTests/` is XCTest (not
swift-testing) and every test in it is synchronous and sub-millisecond. Match
that: no `sleep`, no expectations, no real clocks.

**If it touches `apps/macOS/` or `apps/iOS/`, there is no unit test to write, and
that is the honest answer rather than an excuse.** Every one of the 15 Swift
files under `apps/` imports SwiftUI, AppKit, AVFoundation, Vision or Speech, and
all of the pure helper logic in them (the aspect-fill coordinate mapper, the
Vision bottom-left→top-left flip, the FPS smoother, the head-pose mean) is
declared `private`, which `@testable import` does not defeat. The view models
cannot reach any interesting state without a live `AVCaptureSession`. **CI's
coverage of `apps/` is that it compiles, unsigned, for both targets** — and that
is real coverage, because before this it was compiling nothing at all.

So: **a green CI does not mean your sensor change works.** It means it builds.
Functional validation of anything touching the camera, the microphone or speech
recognition has to happen on your own machine, with real hardware and real
permission prompts — and you record that in the feature doc's Verification line.

**The escape hatch.** If your PR genuinely has nothing to put in
`docs/features/` — a CI-only chore, an `openspec` archive commit, a dependency
bump — say so in the PR description and ask for the **`skip-docs-gate`** label.
Only a maintainer can apply it (it needs write/triage access, so it is not
self-serve), and it is intended for exactly those cases. It is **not** for "I
didn't feel like writing docs": if your change alters behaviour a user or an
agent can observe, it needs a feature doc.

---

## 5. The core must stay platform-agnostic

**`Sources/GazeKit/` may import `Foundation` and nothing else.** No
`AVFoundation`, `Vision`, `ARKit`, `Speech`, `UIKit`, `AppKit`, `SwiftUI`,
`CoreVideo`, `CoreMedia`, `CoreML`, `Combine`. Sensor and UI implementations
belong in `apps/macOS/` or `apps/iOS/`, behind the `GazeSensor` protocol.

This is not a style preference. It is what lets the same core serve a webcam
sensor and an ARKit sensor interchangeably, and it is what lets the core build
and test in seconds without Xcode.

**CI now enforces this mechanically.** The `GazeKit · Linux compile + platform
guard` job greps for a banned import and then compiles the core *and its test
target* on Linux, where an Apple framework simply does not exist. It used to be
enforced only by a human ticking a checkbox in an `openspec` task list. Now an
`import AVFoundation` in the core fails the build with an explicit message.

---

## 6. Checks and review

Every PR runs three required checks. The names, verbatim:

| Check | Runner | What it does |
|---|---|---|
| `CI / GazeKit · Linux compile + platform guard` | `ubuntu-24.04` | Apple-import guard, then `swift build --build-tests`. |
| `CI / GazeKit · macOS tests + app builds` | `macos-15` | `swift build` + `swift test`, then `xcodegen generate` and an unsigned `xcodebuild` of **both** app targets. |
| `PR Gate / Docs gate` | `ubuntu-24.04` | Requires a `docs/features/*.md` change, unless a maintainer applied `skip-docs-gate`. |

> `main` is protected. Pull requests are the only way in. Every PR needs:
>
> - all required checks green,
> - all review conversations resolved,
> - one approving review from a code owner (@Tatendaz).
>
> You cannot approve your own pull request — GitHub does not allow it — so every
> contribution gets a second pair of eyes before it lands.

**Two things that look like broken CI but aren't:**

1. **First-time contributors: your workflow runs sit "pending approval"** until a
   maintainer clicks *Approve and run*. Nothing is wrong; GitHub does this for
   every first-time contributor to every public repo. Wait, or ping the PR.
2. **You do not need any secrets, an Apple ID, a certificate or a provisioning
   profile.** Both app builds pass `CODE_SIGNING_ALLOWED=NO`, so **fork PRs build
   fine**. GitHub deliberately withholds secrets from fork-triggered runs, and
   this repo's PR path is designed to need none. (Signing only matters for
   archiving/notarising/distributing, which will never live in the PR workflow.)

**Review.** Expect two passes: an automated [CodeRabbit](https://coderabbit.ai)
review that will leave inline comments within a few minutes, and then a human
review from a code owner. Address or reply to CodeRabbit's comments and resolve
the threads — that is a normal part of the loop here, not a sign something is
wrong. Look at PRs #5 and #7 for what it looks like in practice.

---

## 7. What must never be in a PR

- **Secrets, API keys, tokens, `.env` files, certificates, provisioning
  profiles.** Nothing in this repo needs them, so anything of the sort in a diff
  is a mistake. `.gitignore` covers the build outputs (`.build/`, `build/`,
  `DerivedData/`, `*.xcodeproj/`) but it does **not** and cannot catch a secret
  you paste into a source file — that is on you and on review.
- **Generated artifacts.** `Vergance.xcodeproj`, `apps/**/Info.plist` and
  `apps/macOS/*.entitlements` are produced by `xcodegen generate` and are
  `.gitignore`d. Change [`project.yml`](project.yml) instead; committing the
  generated output creates a second source of truth that immediately drifts.
- **Camera frames, audio recordings, or any captured sample data.** Vergance's
  central privacy claim is that *raw camera frames never leave the device; only
  semantic events do*. A test fixture containing someone's face contradicts that
  claim in the most literal possible way. If you need fixture data, synthesize
  landmark coordinates — that is what `Tests/GazeKitTests/` already does.
- **A new dependency**, without discussing it in an issue first. `GazeKit` having
  zero dependencies is a feature: it is why there is no install step and why the
  Linux job is a two-second compile.

---

## 8. House style

From [`CLAUDE.md`](CLAUDE.md), which applies to humans just as much as to agents:

1. **Think before coding.** State your assumptions. If there are two reasonable
   interpretations, ask rather than picking one silently.
2. **Simplicity first.** The minimum code that solves the problem. No speculative
   features, no abstractions for single-use code, no configurability nobody asked
   for.
3. **Surgical changes.** Touch only what you must. Match the surrounding style
   even where you'd do it differently. Don't refactor adjacent code and don't
   delete pre-existing dead code — mention it instead.
4. **Goal-driven execution.** Turn the task into something verifiable: *"write a
   failing test, then make it pass"*, not *"make it work"*.

If a security issue is what brought you here, please read
[`SECURITY.md`](SECURITY.md) instead of opening a PR.
