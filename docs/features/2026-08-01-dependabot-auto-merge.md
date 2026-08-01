# Feature: Dependabot auto-merge workflow

**Branch:** ci/dependabot-auto-merge (PR #13, merged 2026-08-01; entry added retroactively by the follow-up docs-gate PR)
**Date:** 2026-08-01 local (2026-08-01 UTC)

## Summary
`.github/workflows/dependabot-auto-merge.yml`: Dependabot patch/minor PRs approve and merge automatically once checks pass; major bumps wait for a human.

## Motivation
Account-wide rollout so Dependabot security bumps stop piling up unmerged.

## What changed
- New workflow (SHA-pinned fetch-metadata; approve step for the 1-review rule; `--match-head-commit`-pinned merge; checks-aware fallback).
- Repo settings: `allow_auto_merge` and Actions PR-approval enabled.

## Notes
PR #13's merge predates this entry — the docs gate was bypassed there with an admin merge; this file squares the ledger.
