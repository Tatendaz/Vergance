# Feature: Agent-readable landing page — `<main>`, Markdown twin, llms.txt links

**Branch:** feat/agent-readiness
**Date:** 2026-08-22

## Summary
Makes `docs/index.html` (the GitHub Pages landing page at https://tatendaz.github.io/Vergance/)
readable for AI agents the same way the root site is: the page content sits inside `<main>`,
a Markdown twin lives at `docs/index.md`, and the page advertises it with
`<link rel="alternate" type="text/markdown" href="/Vergance/index.md">` plus
`<link rel="describedby" href="/llms.txt">`. Nothing visible changes apart from an llms.txt link
in the footer. A custom `docs/404.html` replaces GitHub's generic 404 for missing paths.

## Motivation
An Is Agentic audit of tatendaz.github.io (2026-08-22) showed the scanner counts text and the
H1 only inside `<main>`. This page had no `<main>`, so its 4,000+ characters of static text and
its H1 did not count. The root site's `llms.txt` (Tatendaz/Tatendaz.github.io PR #8) lists
this page; the page now points back at it and ships the Markdown twin that the
[llmstxt.org](https://llmstxt.org/) spec recommends (`index.md` next to `index.html`,
`rel="alternate"` to the twin, `rel="describedby"` to the covering `llms.txt`).

## What changed
- `docs/index.html`: `<main>` wraps the hero and every content section (the footer stays
  outside). The hero was a `<header>`; it is now `<div class="hero">` (CSS selector renamed,
  same rules) because boilerplate-stripping extractors drop `<header>` elements and would
  lose the H1 with it. The two `<link>` tags sit after the canonical; the footer gains an llms.txt link.
  CSS: selector-only change (the one `header` rule is now `.hero`, same declarations); no layout
  change (the stylesheet has no child selectors or `main` rules).
- `docs/index.md`: Markdown twin of the page content, generated from the HTML and then
  hand-checked (the example intent event became a code block). It ends with links back to the HTML version, the
  source, the root site and `llms.txt`.
- Custom 404 — `docs/404.html` (new): served by GitHub Pages for every missing path under
  `/Vergance/`, which used to show GitHub's generic 404. The Is Agentic "Agent-friendly 404s"
  check gives full credit only for a real HTTP 404 whose body carries short Markdown guidance,
  so the page keeps the landing page's chrome, says what happened, lists where to look next
  (docs, Markdown twin, source, `llms.txt`, sitemap, home) and repeats those pointers as plain
  Markdown in a `<pre class="md">` block. Every URL is absolute because Pages serves the file
  at any path depth; `noindex`, no canonical, no `rel="alternate"`.
- `Tests/GazeKitTests/DocsSiteTests.swift` (XCTest, runs under `swift test`): one `<main>`, one `<h1>` inside it, 500+ characters of text; the head links
  are present; the twin starts with the same H1, contains every H2 of the page, and is plain
  Markdown. For the 404 page: the title says 404, `noindex` is set, there is no canonical or
  alternate link, the Markdown block sits inside `<main>`, starts with `# 404`, carries the
  heading and the links, stays under 700 characters and contains no HTML, and every `href`
  is absolute. Run with `swift test --filter DocsSiteTests`.

## Notes
- When the landing page changes, update `docs/index.md` too; the test fails if an H2 goes
  missing from the twin or the H1 drifts.
- Real `Accept: text/markdown` negotiation is not possible on GitHub Pages (no custom
  headers); the twin plus the two links are the static equivalent.
- No per-project `llms.txt`: the root `/llms.txt` covers every path on the host and already
  describes this project.
- The 404 page goes live once this branch is on `main` (Pages publishes `main:/docs`); until
  then missing paths keep showing GitHub's generic 404.
