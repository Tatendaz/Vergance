# Feature: CI hardening + contributor docs

**Branch:** chore/ci-hardening-and-contributor-docs
**Date:** 2026-07-25

## Summary
Consolidates the two duplicate workflows into one Linux job + one macOS job, makes CI compile
the 15 app source files it had never touched, mechanically enforces the platform-agnostic-core
rule, and adds the community files a public repo needs — `CONTRIBUTING.md`, `SECURITY.md`,
`CODEOWNERS`, a PR template. **macOS runners per PR drop from 2 to 1 while coverage goes up.**

## Motivation
`ci.yml` and `pr-gate.yml` each ran `swift build` + `swift test` on `macos-15`, so every PR to
main paid for the identical macOS build+test twice — and between them they compiled **zero** of
the code under `apps/`. Meanwhile the project's own rules (OpenSpec, the Foundation-only core,
the `docs/features/` convention) lived only in `CLAUDE.md` and agent skill files, where an
outside contributor could not find them, and the docs gate had no escape hatch — replaying it
over real history, `9e073a5` (openspec archive) and `8bbd8b6` (README expansion) would both have
been rejected outright.

## What changed
- **`.github/workflows/ci.yml`** — rewritten as two jobs:
  - `GazeKit · Linux compile + platform guard` on `ubuntu-24.04`: an explicit grep guard for
    Apple-only imports in `Sources/GazeKit` and `Tests/GazeKitTests`, then
    `swift build --build-tests`. Together these *mechanically* catch the failure the
    "core imports only Foundation" rule exists to prevent — an Apple-only import landing in
    the core — and keep it Linux-buildable, where previously that depended on a human ticking
    `openspec/.../tasks.md` item 1.6. Note the narrower guarantee: the grep matches a named
    list of Apple frameworks and the compile proves the core builds on Linux, so neither
    enforces a literal Foundation-only allowlist. A non-Apple, non-Foundation dependency
    would still pass; catching that stays a review-time judgement.
  - `GazeKit · macOS tests + app builds` on `macos-15`: the authoritative `swift test`, then
    `xcodegen generate` and an **unsigned** `xcodebuild` of **both** `Vergance` (macOS) and
    `VerganceCompanion` (iOS Simulator). `CODE_SIGNING_ALLOWED=NO` is what keeps fork PRs
    building with no secrets.
  - `ubuntu-24.04` is pinned **on purpose, with a comment saying why**: that image ships Swift
    6.3.3, the `ubuntu-26.04` image ships no Swift at all, so `ubuntu-latest` is a time bomb.
  - `swift test` is deliberately *not* run on Linux — the bundle builds and links there, then
    hangs (exit 124) in every local reproduction across Swift 6.1.3/6.3.3 and aarch64/x86_64.
- **`.github/workflows/pr-gate.yml`** — reduced from 69 lines to the docs gate alone, moved off
  `macos-15` onto `ubuntu-24.04` (it is a `git diff | grep`; it never needed Apple hardware).
  Gains a **`skip-docs-gate` label bypass**, drops `persist-credentials: true` (the base commit
  is already local with `fetch-depth: 0`, so the authenticated `git fetch` was unnecessary), and
  diffs `base.sha` directly.
- **Hardening applied to both** — `permissions: contents: read`; per-PR `concurrency` that
  **never cancels a main build**; `timeout-minutes` on every job (10/30/5) where there was
  previously GitHub's 6-hour default; every action pinned to a commit SHA (`ci.yml` had been
  using the mutable `actions/checkout@v4`); `persist-credentials: false`; SwiftPM build caching;
  `set -euo pipefail` in every script step; no untrusted event input reaching a shell.
- **`CONTRIBUTING.md`** (new) — makes the OpenSpec workflow discoverable to humans for the first
  time: the `/opsx:` propose → apply → sync → archive lifecycle, when it is required vs. when a
  small fix can skip it, `openspec validate <change> --strict`, and the document shapes. Also
  the platform-agnostic-core rule (and that CI now enforces it), the `docs/features/`
  requirement with a worked example, why `docs/summaries/` is absent, the three required check
  names verbatim, the first-time-contributor "pending approval" surprise, and the "no signing
  needed, fork PRs build fine" reassurance.
- **`SECURITY.md`** (new) — a disclosure channel for a public repo that handles camera,
  microphone and speech data while declaring network client+server entitlements. States the
  privacy claim precisely, names the files where sensitive processing happens, and flags the
  unused Phase 7 network entitlements as the honest wart.
- **`.github/CODEOWNERS`**, **`.github/PULL_REQUEST_TEMPLATE.md`** (new) — route review to
  @Tatendaz and checklist the docs/openspec/ROADMAP steps at the moment a PR is opened.
- **`.gitignore`** — added `build/` alongside the existing `.build/`, `DerivedData/` and
  `*.xcodeproj/` entries.

## Notes
- **No tests were added for `apps/`, and that is deliberate.** All 15 Swift files there import
  SwiftUI/AppKit/AVFoundation/Vision/Speech, and every pure helper in them — the aspect-fill
  `Mapper`, `VisionFaceDetector.imagePoint`/`corners`, `ProbeViewModel.updateFPS`,
  `CalibrationViewModel.meanPose` — is `private`, which `@testable import` does not defeat
  (verified: a probe test target compiled against them fails with *"'imagePoint' is inaccessible
  due to 'private' protection level"* / *"cannot find 'Mapper' in scope"*). The only reachable
  surface is one-line derived properties and static demo data. Reaching the real logic would
  need an access-control refactor of production code, which is out of scope here. **The unsigned
  compile of both app targets is the honest coverage**, and it is strictly more than the zero
  they had before.
- The docs gate's `docs/features/*.md` glob was re-verified against all 8 real filenames and
  against this PR's own diff before landing.
- This change is a CI/docs chore with no capability delta, so it does not carry an
  `openspec/changes/` entry — applying the same "when can I skip OpenSpec" rule this PR writes
  down in CONTRIBUTING.md.
- **Not verified:** these workflows have not yet executed on GitHub Actions. The likeliest
  friction points are the `xcodebuild` destination strings against the runner's Xcode and
  `brew install xcodegen` duration. The Linux `swift test` hang also remains unproven on a bare
  runner (every reproduction was inside Docker on macOS); `ci.yml` carries a comment explaining
  the one-line experiment that would settle it.
- Verification: `swift build` clean; `swift test` **48/48 green, 0 failures**; `xcodegen
  generate` clean; both app targets `** BUILD SUCCEEDED **` unsigned via headless `xcodebuild`
  (Xcode 26.6 / 17F113, Swift 6.3.3). Both workflow files parse as YAML; all 10 `run:` blocks
  pass `shellcheck` with zero findings; both action SHA pins re-verified against the GitHub API.
  The import guard was re-tested with 1 positive, 4 negative and 2 false-positive controls, and
  the docs gate was simulated against this PR's real diff (PASS) and against a
  feature-doc-removed variant (correctly FAIL, then PASS under the `skip-docs-gate` label).
