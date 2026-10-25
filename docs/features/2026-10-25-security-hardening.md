# Feature: Dependency cooldown and workflow lint

**Branch:** security/hardening-2026-10-25
**Date:** 2026-10-25

## Summary
Dependabot now opens at most one batched PR per ecosystem per month, for
releases at least 7 days old. A new `zizmor` workflow fails any PR that adds a
high-severity workflow issue.

## Motivation
Several worms in August to October 2026 shipped as new versions of trusted
packages and actions, and were pulled within days. A 7-day wait skips most of
them. zizmor found the two unpinned actions fixed in #18; the job keeps that
from coming back.

## What changed
- `.github/dependabot.yml` (new): `swift` and `github-actions`, monthly,
  `cooldown.default-days: 7`, one minor+patch group each, at most 3 open PRs.
- `.coderabbit.yaml` (new): `reviews.auto_review.ignore_usernames:
  ["dependabot[bot]"]`, so Dependabot PRs do not spend CodeRabbit reviews.
- `.github/workflows/zizmor.yml` (new): `pipx run zizmor==1.31.1 --offline
  --min-severity high .github/workflows`.
- `.github/workflows/dependabot-auto-merge.yml`: top-level token is now
  `contents: read`; the write scopes moved onto the one job that needs them.

## Notes
- SwiftPM has no release-age setting, so there is no package-manager cooldown.
  `GazeKit` has no package dependencies today.
- `ci.yml` still runs `brew install xcodegen` unpinned on the hosted macOS
  runner. Homebrew has no per-formula version pin for this.
