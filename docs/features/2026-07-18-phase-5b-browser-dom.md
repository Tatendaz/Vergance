# Feature: Phase 5b — element resolution (browser DOM)

**Branch:** feat/phase-5b-browser-dom
**Date:** 2026-07-18

## Summary
Gaze now resolves against a **web page's DOM**. A Vergance-hosted `WKWebView` becomes the second
staged surface — **(b) browser DOM** (roadmap §6 #4) — after (a) the own canvas: an injected script
extracts the page's labeled, hit-test-worthy elements, Swift maps their viewport rects into the
normalized gaze space, and the existing resolution path does the rest. Utterances and fixations over
the page carry real DOM ids (`cta-primary`, `nav-docs`, …) instead of region placeholders. The
Accessibility-API surface (c) extends the same capability later.

## What changed
- **GazeKit** (platform-agnostic, +6 tests → 54 total green):
  - `Rect.place(x:y:width:height:viewportWidth:viewportHeight:)` — maps a DOM rect (viewport CSS
    pixels) into a normalized surface `Rect`, given the viewport size and the web view's normalized
    frame within the surface (the receiver). Pure geometry; the core stays WebKit-free. Degenerate
    (zero-size) viewports return an empty rect instead of trapping.
  - The resolution path is untouched — the DOM is only a *source* for the `ElementMap`;
    `ElementMap.resolve` → fuser/fixation wiring is unchanged from Phase 5a.
- **OpenSpec:** new `dom-resolution` capability (proposal/design/specs/tasks);
  `element-resolution` unchanged (already surface-agnostic).
- **apps/macOS:**
  - `BrowserSurface.swift` — a `WKWebView` loading a bundled demo page (`loadHTMLString`, no
    resource-bundling dependency) with deterministic ids across links, buttons, an input, headings,
    an `aria-label`ed button, and unlabeled buttons that exercise the generated-selector path. A
    `WKUserScript` (document end, main frame, re-runs per navigation) collects visible, on-viewport
    elements — DOM `id` or a generated `nth-of-type` CSS path, role, `aria-label`/text,
    `getBoundingClientRect` + viewport size, capped at 200 with a console warning — debounced
    ~120 ms on scroll/resize/load, and posts them over a `WKScriptMessageHandler`. The coordinator
    maps each rect via `Rect.place` (the web view fills the surface, so the frame is the full
    `[0, 1]` space) and registers the resulting `ElementMap` into `CalibrationViewModel`.
  - `GazeCursorView` — a segmented **Canvas / Browser** picker chooses the Run surface; the gaze
    cursor, fixation discs, and resolved-target readout overlay both. Switching re-registers the
    element map (the browser surface starts empty until its first extraction lands, so resolution
    falls back to region ids meanwhile — the "speech without gaze still emits" guarantee holds).

## Notes
- One conversion at extraction time keeps DOM elements and the gaze cursor in a single normalized
  coordinate space; scroll/resize/navigation re-extraction keeps the map tracking the live page.
- A bundled demo page (not a URL bar) was chosen deliberately: known ids make on-device validation
  deterministic. Arbitrary-page browsing is future work on the same surface.
- Verification: `swift test` 54/54 green; GazeKit still imports no WebKit/AVFoundation/Vision/
  Speech/ARKit; the macOS app `BUILD SUCCEEDED` via headless `xcodebuild`. **On-device validation
  (task 2.6) is pending** — look at a page link/button while speaking and confirm the utterance's
  `primaryTarget`/`gazeTargets` carry that element's DOM id; planned as a joint session.
