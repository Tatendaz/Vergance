# Feature: Social preview image for the landing page

**Branch:** feat/docs-social-preview
**Date:** 2026-07-26

## Summary
Adds `docs/social-preview.png` and wires it up as `og:image` / `twitter:image`, so links
to `https://tatendaz.github.io/Vergance/` let consumers that support it render a large
image card instead of a bare title-and-description card. Support varies by platform —
X and Slack honour it; others fall back to the title and description, which is what was
rendering before.

## Motivation
The repo already had a custom social preview configured in GitHub Settings, but that only
covers links to `github.com/Tatendaz/Vergance`. The landing page is a different URL with
its own metadata, and it had no `og:image` at all — so the page that gets posted during
launch week rendered as plain text on X, LinkedIn and Slack while the repo link rendered
a card. Two destinations, two separate pieces of configuration.

## What changed
- `docs/social-preview.png` — 1280×640, the Obsidian-system card generated from
  `github-social-kit/social-previews/template.html#vergance`.
- `docs/index.html`
  - `og:image`, `og:image:width`, `og:image:height`, `og:image:alt`.
  - `twitter:image`.
  - `twitter:card` flipped from `summary` to `summary_large_image`, and the comment
    explaining why it was `summary` is removed — its condition no longer holds.

## Notes
- **The file is 1280×640, matching the declared `og:image:width`/`height`.** The card is
  rendered at 2560×1280 for the GitHub Settings upload, but the copy served here is the
  1× export: declaring dimensions that don't match the bytes misleads the scraper's layout
  pass. `render.sh` now emits both sizes so the two can't drift.
- **`og:image:alt` describes the card's actual content**, including the text in the
  terminal strip. It is image-description metadata that consumers supporting it can expose
  assistively, so it reads as a description rather than a repetition of the title.
- Matches the setup `yapui` and `claude-usage` already use, down to the filename.
