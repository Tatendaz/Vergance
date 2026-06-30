## Context

Phase 5 (a) shipped `ElementMap.resolve` and wired the own-canvas surface. The resolution path is
**surface-agnostic** — it resolves a gaze point against whatever `ElementMap` it's handed, with a
geometric region-id fallback. Phase 5 (b) adds a new **source** for that map: a web page's DOM, read
from a Vergance-hosted `WKWebView`.

Constraints (CLAUDE.md / ROADMAP):
- **GazeKit stays platform-agnostic** — no WebKit. The DOM extraction (JS + `WKWebView`) is app-side;
  only the pure DOM-rect → normalized-`Rect` geometry goes in GazeKit.
- **One coordinate space** — DOM rects (viewport CSS pixels) must map into the same normalized
  `[0, 1]` surface space as the gaze cursor, or hit-testing is meaningless (the recurring rule).
- **Resolution path unchanged** — `UtteranceFuser`, `FixationEvent`, and the `element-resolution`
  capability are not touched; Phase 5b only populates the map differently.

## Goals / Non-Goals

**Goals:**
- Extract labeled, hit-test-worthy elements from a hosted web page's DOM (id/role/label + rect).
- Map them into a normalized `ElementMap` in the gaze cursor's coordinate space.
- Feed the existing resolution path; keep the region fallback.
- Re-extract on scroll / resize / navigation, debounced.

**Non-Goals:**
- **External browsers** (Safari/Chrome) — needs an extension or the Accessibility API; out of scope.
- **Surface (c) Accessibility API** — the separate next sub-phase.
- **Changing** the fuser, fixation path, or `element-resolution` capability.
- **Semantic page understanding** beyond id/role/label/rect.

## Decisions

### 1. Hosted `WKWebView`, JS extraction over a message handler
Vergance renders the page in a `WKWebView` and injects a script that collects elements and posts
them to Swift via a `WKScriptMessageHandler`. *Alternative:* read an external browser's DOM —
rejected; needs a browser extension or the Accessibility API (surface (c) / out of scope).

### 2. Pure geometry in GazeKit, capture in the app
The DOM-rect → normalized-`Rect` mapping is pure math (viewport size + the web view's normalized
frame) → GazeKit, unit-tested. The `WKWebView` + JS bridge is app-side. Mirrors the 5a layering and
keeps the core WebKit-free.

### 3. Same `ElementMap` API
Extracted elements become `[Element]` → `ElementMap`, resolved by the unchanged `resolve`. No new
resolution logic — the DOM is just a populator. *Why:* the staged-surface design (roadmap §6 #4) —
own-canvas, DOM, and AX all feed one resolver.

### 4. Element selection + id strategy
Extract plausible gaze targets — interactive/labeled elements (links, buttons, inputs, `[role]`,
headings, `[aria-label]`) — skipping hidden, zero-area, or off-viewport nodes. Id = the DOM `id`
when present, else a generated stable CSS selector (an `nth-of-type` path). *Trade-off:* generated
selectors are less semantic than authored ids but stable enough to name a target across
re-extractions.

### 5. Coordinate mapping via `getBoundingClientRect`
`getBoundingClientRect` is viewport-relative (scroll already applied), so a DOM rect `(dx,dy,dw,dh)`
over a viewport `(W,H)` within the web view's normalized surface frame `(vx,vy,vw,vh)` maps to
`(vx + dx/W·vw, vy + dy/H·vh, dw/W·vw, dh/H·vh)`. This is the GazeKit helper, the single source of the
mapping.

### 6. Debounced re-extraction
Re-extract on `scroll` / `resize` / navigation, debounced (~100–150 ms), so a scroll gesture doesn't
thrash the map. Between updates the map is briefly stale; resolution degrades to the region fallback,
never crashes.

## Risks / Trade-offs

- **Coordinate drift (viewport vs. web-view frame vs. surface)** → the GazeKit helper is the single,
  unit-tested mapping; the app supplies the web view's normalized frame from its layout. Verify by
  running the app and confirming a looked-at link resolves to its id (the checkpointed step).
- **DOM churn / SPA route changes** → re-extract on navigation + a debounced scroll/resize trigger;
  accept brief staleness (resolution falls back to region ids, never crashes).
- **Huge pages (thousands of elements)** → extract only plausible targets (interactive/labeled,
  visible, above a min size); `log` if a cap is hit so coverage loss isn't silent.
- **Generated-selector instability across re-extraction** → prefer authored ids; generated selectors
  are best-effort labels, adequate for a single utterance's target.
- **Web view ↔ gaze clock** → extraction defines space, not events; the map is sampled at fusion /
  fixation time (like 5a), so there's no new clock concern.

## Migration Plan

Additive; the own-canvas surface and the fuser/fixation path are untouched. Ship the GazeKit geometry
helper first (verified by `swift test`), **checkpoint**, then the `WKWebView` surface + JS bridge +
wiring (verified by running the app). Rollback is removing the browser surface — 5a behavior remains.

## Open Questions

- Default page for the Run-mode browser surface — start with a **bundled local demo page** with
  known ids for deterministic validation; a URL bar can come later.
- Surface selection (own-canvas vs. browser) — start with the browser as the Run surface behind a
  simple toggle, reusing the 5a cursor/fixation/utterance overlays.
- Element-selection heuristics (which roles count, min size) — tune against the demo page.
