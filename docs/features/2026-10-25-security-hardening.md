# Feature: Dependency cooldown and workflow lint

**Branch:** security/hardening-2026-10-25
**Date:** 2026-10-25

## Summary
Dependabot now batches minor and patch updates into one PR per ecosystem per
month (major bumps open on their own, at most 3 open PRs in all), only for
releases at least 7 days old. A new `zizmor` workflow fails any PR that adds a
medium- or high-severity issue to the workflows or `dependabot.yml`.

## Motivation
Several worms in August to October 2026 shipped as new versions of trusted
packages and actions, and were pulled within days. A 7-day wait skips most of
them. zizmor found the two unpinned actions fixed in #18; the job keeps that
from coming back.

## What changed
- `.github/dependabot.yml` (new): `swift` and `github-actions`, monthly,
  `cooldown.default-days: 7`, one minor+patch group each, at most 3 open PRs.
- `.github/workflows/merge-when-clean.yml` (new, owner template, unchanged):
  every 30 minutes and on status events, merges Dependabot PRs and the owner's
  `security/*` or `automerge`-labelled PRs once CI is green, a real review ran
  (CodeRabbit "Review completed" or `review-failover` success) and 0 threads
  are open.
- `.github/workflows/zizmor.yml` (new): `pipx run zizmor==1.31.1 --offline
  --min-severity medium .`. Scanning the repo root covers
  `dependabot.yml` too, so removing the cooldown fails the job.
- `.github/workflows/dependabot-auto-merge.yml` (deleted): it merged
  Dependabot patch/minor PRs on green CI with no review. `merge-when-clean.yml`
  now merges non-major Dependabot PRs, and only after a real review.

## Notes
- SwiftPM has no release-age setting, so there is no package-manager cooldown.
  `GazeKit` has no package dependencies today.
- `ci.yml` still runs `brew install xcodegen` unpinned on the hosted macOS
  runner. Homebrew has no per-formula version pin for this.
