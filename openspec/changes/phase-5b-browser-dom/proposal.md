## Why

Phase 5 (a) resolves gaze to named elements on Vergance's **own canvas** — a demo of four
hard-coded tiles. Real targets live in real UIs. Surface **(b)** reads a **web page's DOM** so gaze
resolves to actual page elements (`cta-primary` on a live site) — the first staged surface that
works beyond our own canvas (roadmap §6 #4). The resolution path is unchanged: this only adds the
DOM as a new **source** for the `ElementMap`.

## What Changes

- **New `dom-resolution` capability**: the macOS app hosts a `WKWebView`; injected JavaScript walks
  the DOM for labeled, hit-test-worthy elements — a stable id (the element's `id`, else a generated
  CSS selector), plus role / `aria-label` / text, and `getBoundingClientRect` — and posts them to
  Swift over a `WKScriptMessageHandler`. Swift maps each DOM viewport-pixel rect to a normalized
  surface `Rect` and builds an `ElementMap`.
- **Feeds the existing resolution path unchanged**: the resulting `ElementMap` flows into
  `ElementMap.resolve` → the fuser and fixation events exactly as the own-canvas map does.
  `element-resolution`, `UtteranceFuser`, and `FixationEvent` are **untouched** — same API, new
  surface. A gaze that hits no DOM element still falls back to the geometric region id.
- **Live tracking**: re-extract the DOM on scroll, resize, and navigation so the map tracks the live
  page; debounce so churn doesn't thrash resolution.
- **GazeKit geometry helper** (platform-agnostic, unit-tested): map a DOM rect (viewport CSS pixels)
  given the viewport size and the viewport's normalized frame within the surface → a normalized
  `Rect`. Pure math, no WebKit.
- **macOS Run-mode wiring**: a `WKWebView` browser surface on the Run screen, the JS bridge, the
  coordinate mapping, registration into `CalibrationViewModel`, and the gaze cursor + resolved-target
  readout over the page.

**Scope boundary.** Only Vergance's **hosted** `WKWebView`. Resolving against an **external** browser
(Safari/Chrome) needs a browser extension or the Accessibility API and is out of scope; surface
**(c)** the macOS Accessibility API is the separate next sub-phase. No changes to speech, fusion, or
the event schema.

## Capabilities

### New Capabilities
- `dom-resolution`: extract a web page's labeled elements from the DOM (id/role/label + bounding
  rect) and map them to a normalized-`Rect` `ElementMap` for the shared element-resolution path,
  re-extracted as the page scrolls / resizes / navigates.

### Modified Capabilities
<!-- None. `element-resolution` is surface-agnostic and unchanged; Phase 5b only adds the DOM as a
     new source for the ElementMap it already resolves against. -->

## Impact

- **GazeKit**: one new pure geometry helper (DOM-rect → normalized `Rect`) + unit tests. Stays
  platform-agnostic — no WebKit/AVFoundation/Vision/Speech/ARKit. `Element`/`Rect`/`ElementMap`/
  `resolve` are reused as-is.
- **apps/macOS**: a `WKWebView` browser surface, a JS extraction script + `WKScriptMessageHandler`
  bridge, the coordinate mapping, `CalibrationViewModel` registration, scroll/resize/navigation
  re-extraction, and Run-screen integration. Links `WebKit.framework`.
- **Privacy**: the page renders locally; only the extracted element geometry/labels feed resolution,
  and only the semantic `Utterance` leaves the perception layer — unchanged posture.
- **Non-breaking**: additive; the own-canvas surface (5a) and the empty-map region fallback are
  unaffected.
