<!--
Thanks for contributing! The checklist below records this repository's
contribution requirements. CI enforces some of them — the builds, the tests
and the docs/features entry. A reviewer enforces the rest, so a green build
does not mean the checklist is satisfied.
-->

## What this changes

<!-- One or two sentences. What does this do, and why? -->

## Why

<!-- The problem being solved, or the capability being added. Link an issue with "Closes #N" if there is one. -->

## Checklist

- [ ] **Branch is named `<type>/<slug>`** — one of `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`.
      GitHub's web "Edit this file" button creates branches named `patch-1`, which fails the docs gate.
- [ ] **Tests pass locally** — `swift build && swift test` (48 tests today; no Xcode needed).
- [ ] **App targets still build** if you touched `apps/` —
      `xcodegen generate`, then `xcodebuild build -scheme Vergance -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`.
      CI does this for both targets; nothing under `apps/` is unit-testable, so the compile *is* the coverage.
- [ ] **Changes to `Sources/GazeKit/` come with test changes.** The core is pure logic — there is no
      untestable change there. CI compiles the core on Linux, so it may import **only Foundation**.
- [ ] **`docs/features/<YYYY-MM-DD>-<slug>.md` exists** describing what changed and why.
      This one is a hard CI gate. If your PR genuinely has nothing to document (a chore, an openspec
      archive), say so here and ask a maintainer to apply the `skip-docs-gate` label.
- [ ] **`docs/summaries/` is NOT required in this repo** — it is `.gitignore`d (local-only, privacy).
      Nothing to do; noted so you don't go looking for it.
- [ ] **Non-trivial change?** An `openspec/changes/<kebab-name>/` entry exists and
      `openspec validate <change> --strict` passes. See CONTRIBUTING.md for when this is required.
- [ ] **`ROADMAP.md` phase row updated**, if this moves a phase forward.
- [ ] **No secrets, API keys, or `.env` files** are included in the diff.
      Also no generated artifacts (`Vergance.xcodeproj`, `Info.plist`, `*.entitlements`) and no real
      camera or audio capture data.

## Verification

<!--
How did you actually check this? CI can only prove the app COMPILES — it has no camera,
no microphone and no speech permission. If your change touches capture, say what you
validated on-device.
-->

- `swift test`:
- App build:
- On-device:

## Notes for the reviewer

<!-- Anything surprising, any tradeoff you made, anything you want a second opinion on. Delete if not needed. -->
