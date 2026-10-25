# Feature: Pin the dependency-review actions to commit SHAs

**Branch:** security/sweep-2026-10-25
**Date:** 2026-10-25

## Summary
`.github/workflows/dependency-review.yml` now names both actions by full commit
SHA, and its checkout no longer leaves the job token in `.git/config`.

## Motivation
The file used `actions/checkout@v5` and `actions/dependency-review-action@v4`.
A tag can be moved to new code by whoever controls the action repo, so every
PR run would pick up that code with no change here. The other workflows in
this repo already pin by SHA; this was the one left. zizmor flagged two
`unpinned-uses` errors and one `artipacked` warning on it.

## What changed
- `actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5.1.0`, with
  `persist-credentials: false`.
- `actions/dependency-review-action@2031cfc080254a8a887f58cffee85186f0e49e48 # v4.9.0`.
- Same majors as before, so no behaviour change is expected.

## Notes
- Part of the 2026-10-25 security sweep. zizmor now reports no findings on
  `.github/workflows/`.
