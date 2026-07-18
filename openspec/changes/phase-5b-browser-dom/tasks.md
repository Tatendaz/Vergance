## 1. GazeKit core — DOM-rect → normalized `Rect` geometry (headless, `swift test`)

- [x] 1.1 Add a pure helper that maps a DOM rect (viewport CSS pixels) given the viewport size and the viewport's normalized frame within the surface → a normalized `Rect` (origin top-left), per design Decision 5. Lives in GazeKit; no WebKit import.
- [x] 1.2 Unit tests: a rect at the viewport origin maps to the frame origin; a full-viewport rect maps to the full frame; a centered rect maps to the frame centre; a web view occupying a sub-frame offsets + scales correctly; a degenerate viewport (zero size) is handled without trapping.
- [x] 1.3 `swift build && swift test` all green; confirm GazeKit still imports no WebKit/AVFoundation/Vision/Speech/ARKit.

## 2. macOS app — WKWebView browser surface + DOM extraction (needs Xcode/GUI; CHECKPOINT before starting)

- [x] 2.1 Add a `WKWebView` browser surface to the Run screen, loading a bundled local demo page with known ids (links / buttons / headings) for deterministic validation. — `BrowserSurface.swift`; page compiled in and loaded via `loadHTMLString` (no resource-bundling dependency).
- [x] 2.2 Inject a JS extraction script that collects hit-test-worthy elements (DOM id or a generated CSS selector, role / `aria-label` / text, `getBoundingClientRect` + viewport size), skipping hidden / zero-area / off-viewport nodes, and posts them to Swift via a `WKScriptMessageHandler`.
- [x] 2.3 In Swift, map each extracted DOM rect to a normalized surface `Rect` via the GazeKit helper (using the web view's normalized frame within the Run surface), assemble an `ElementMap`, and register it into `CalibrationViewModel`. — `Coordinator.map` uses `Rect.place`; web view fills the surface, so the frame is the full `[0,1]`.
- [x] 2.4 Re-extract (debounced) on scroll, resize, and navigation (`didFinish`) so the map tracks the live page. — JS `scroll`/`resize`/`load` listeners debounced ~120ms; navigation covered by re-injecting the `WKUserScript` at document end on every load.
- [x] 2.5 Run-screen integration: overlay the gaze cursor + fixation markers + resolved-target readout over the web view (reuse the 5a overlays), with a simple toggle between the own-canvas and browser surfaces. — segmented Canvas/Browser picker in `GazeCursorView`.
- [ ] 2.6 Build (`xcodebuild`) and validate on-device: look at a page link/button while speaking → the utterance's `primaryTarget`/`gazeTargets` carry that element's id. — **compiles clean (`BUILD SUCCEEDED`); on-device validation pending (needs camera/mic/GUI).**

## 3. Docs, spec sync & gate

- [x] 3.1 Add a `docs/features/` entry for Phase 5 surface (b) browser-DOM resolution. — `docs/features/2026-07-18-phase-5b-browser-dom.md`
- [x] 3.2 Add the session/summary entry for this session. — `docs/summaries/2026-07-18-phase-5b-browser-dom.md` (local-only; the directory is gitignored by design)
- [x] 3.3 Update the ROADMAP Phase 5 row: surfaces (a) + (b) done, (c) Accessibility API still pending. — (b) marked **built**, on-device validation (2.6) explicitly still pending
- [x] 3.4 `openspec validate phase-5b-browser-dom --strict` passes.
