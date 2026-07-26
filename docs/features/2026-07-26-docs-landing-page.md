# Feature: Landing page at docs/index.html

**Branch:** feat/docs-landing-page
**Date:** 2026-07-26

## Summary
Adds a self-contained `docs/index.html` landing page (plus `docs/.nojekyll`) so Vergance
can be published on GitHub Pages at `https://tatendaz.github.io/Vergance/` and submitted
to search engines.

## Motivation
Vergance had no web page. `https://tatendaz.github.io/Vergance/` returned 404 and Pages
was never enabled, so there was nothing to submit to Google or Bing — the repo's `homepage`
field pointed at the portfolio root, which made it *look* like a site existed when none did.

## What changed
- `docs/index.html` — one file, no build step, no external requests (inline CSS, inline SVG
  favicon).
  - SEO head: `<title>`, meta description, `rel=canonical`, Open Graph, Twitter card.
  - Structured data: `SoftwareApplication` (with `softwareVersion: pre-alpha`) + `FAQPage`
    declaring exactly the four Q&A pairs the page renders, no more.
  - Content: hero with the semantic-event example, what-it-is, the two product surfaces,
    the honest accuracy bar, what's in the core, explicit non-goals, status, FAQ.
- `docs/.nojekyll` — skip Jekyll processing, matching `yapui` and `claude-usage`.

## Notes
- **The page leads with the pre-alpha status**, in a bordered pill directly under the
  tagline and again in the structured data. Eye tracking is a field that attracts
  overclaiming, and the README is careful about this; a landing page that quietly dropped
  the caveat would be the one place the project oversold itself.
- **The accuracy bar and the non-goals get their own sections** rather than being buried.
  "2×2 quadrant reliable, not enough to distinguish adjacent buttons" and "no silent
  lipreading" are differentiators, not disclaimers.
- **Every claim comes from `README.md`** — accuracy figures, calibration method, filter,
  event names, licence, platform floors — so the two can't drift apart.
- **Canonical URL uses the repo's capitalisation** (`/Vergance/`, not `/vergance/`), because
  GitHub Pages project URLs are case-sensitive.
- **No `og:image`.** The repo has no `social-preview.png`; link previews fall back to title
  and description until one exists. `ROADMAP.md` notes the README has no images either —
  worth a combined pass.
- **Pages still needs enabling** (Settings → Pages → `main` / `/docs`) after merge.
