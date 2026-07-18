import GazeKit
import SwiftUI
import WebKit

/// Phase 5 surface (b) — browser DOM. A Vergance-hosted `WKWebView` renders a bundled demo page;
/// an injected script extracts the page's labeled, hit-test-worthy elements and posts them to Swift,
/// where each DOM viewport rect is mapped into the normalized surface space (via GazeKit's
/// ``Rect/place(x:y:width:height:viewportWidth:viewportHeight:)``) and handed back as `[Element]`.
/// The web view fills the whole Run surface, so its normalized frame is the full `[0, 1]` cursor
/// space — the same space the gaze cursor and fixations live in.
///
/// The DOM is only a *source* for the map; the resolution path (``ElementMap/resolve(_:...)`` →
/// fuser + fixation) is unchanged. GazeKit stays WebKit-free — only this app-side file imports it.
struct BrowserSurface: NSViewRepresentable {
    /// Called on the main actor after each extraction with the DOM elements mapped into the
    /// normalized surface space. Wiring point for `CalibrationViewModel.registerElements`.
    var onElements: @MainActor ([Element]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onElements: onElements) }

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: Coordinator.messageName)
        controller.addUserScript(
            WKUserScript(source: Self.extractionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.loadHTMLString(Self.demoPage, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.messageName)
    }

    /// Receives the JS extraction payload (delivered on the main thread by WebKit), maps each DOM
    /// rect into the normalized surface space, and forwards the resulting elements.
    final class Coordinator: NSObject, WKScriptMessageHandler {
        static let messageName = "gazeElements"
        private let onElements: @MainActor ([Element]) -> Void

        init(onElements: @escaping @MainActor ([Element]) -> Void) { self.onElements = onElements }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            let elements = Self.map(message.body)
            // WKScriptMessageHandler callbacks are delivered on the main thread.
            MainActor.assumeIsolated { onElements(elements) }
        }

        /// Map a `{ viewportWidth, viewportHeight, elements: [{id, role, label, x, y, width, height}] }`
        /// payload into normalized surface elements. The web view fills the surface, so the frame is
        /// the full `[0, 1]` space. Pure — no actor state.
        static func map(_ body: Any) -> [Element] {
            guard let body = body as? [String: Any],
                  let vw = (body["viewportWidth"] as? NSNumber)?.doubleValue,
                  let vh = (body["viewportHeight"] as? NSNumber)?.doubleValue,
                  let raw = body["elements"] as? [[String: Any]] else { return [] }
            let frame = Rect(x: 0, y: 0, w: 1, h: 1)
            return raw.compactMap { d in
                guard let id = d["id"] as? String,
                      let x = (d["x"] as? NSNumber)?.doubleValue,
                      let y = (d["y"] as? NSNumber)?.doubleValue,
                      let w = (d["width"] as? NSNumber)?.doubleValue,
                      let h = (d["height"] as? NSNumber)?.doubleValue else { return nil }
                let rect = frame.place(x: x, y: y, width: w, height: h, viewportWidth: vw, viewportHeight: vh)
                return Element(id: id, role: d["role"] as? String, label: d["label"] as? String, rect: rect)
            }
        }
    }

    /// Injected at document end (so it re-runs on every navigation): collect interactive/labeled,
    /// visible, on-viewport elements — id (DOM `id` or a generated `nth-of-type` selector), role,
    /// aria-label/text, and `getBoundingClientRect` — and post them with the viewport size. Scroll,
    /// resize, and load are debounced so a gesture doesn't thrash the map.
    static let extractionScript = #"""
    (function () {
      const MAX = 200;
      const SELECTOR = 'a[href], button, input, select, textarea, summary, [role], [aria-label], h1, h2, h3';

      function cssPath(el) {
        const parts = [];
        while (el && el.nodeType === 1 && el.tagName !== 'HTML' && el.tagName !== 'BODY') {
          let part = el.tagName.toLowerCase();
          const parent = el.parentElement;
          if (parent) {
            const sameTag = Array.prototype.filter.call(parent.children, c => c.tagName === el.tagName);
            if (sameTag.length > 1) part += ':nth-of-type(' + (sameTag.indexOf(el) + 1) + ')';
          }
          parts.unshift(part);
          el = el.parentElement;
        }
        return parts.join('>') || 'body';
      }

      function visible(el, r) {
        if (r.width <= 1 || r.height <= 1) return false;
        if (r.bottom <= 0 || r.right <= 0 || r.top >= innerHeight || r.left >= innerWidth) return false;
        const s = getComputedStyle(el);
        if (s.visibility === 'hidden' || s.display === 'none' || +s.opacity === 0) return false;
        return true;
      }

      function extract() {
        const seen = new Set();
        const elements = [];
        const nodes = document.querySelectorAll(SELECTOR);
        for (let i = 0; i < nodes.length; i++) {
          const el = nodes[i];
          const r = el.getBoundingClientRect();
          if (!visible(el, r)) continue;
          const id = el.id || cssPath(el);
          if (seen.has(id)) continue;
          seen.add(id);
          const label = (el.getAttribute('aria-label') || el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 80);
          elements.push({
            id: id,
            role: el.getAttribute('role') || el.tagName.toLowerCase(),
            label: label || null,
            x: r.left, y: r.top, width: r.width, height: r.height
          });
          if (elements.length >= MAX) { console.warn('[gaze] element cap ' + MAX + ' hit; page truncated'); break; }
        }
        webkit.messageHandlers.gazeElements.postMessage({
          viewportWidth: innerWidth, viewportHeight: innerHeight, elements: elements
        });
      }

      let timer = null;
      function schedule() { clearTimeout(timer); timer = setTimeout(extract, 120); }
      addEventListener('scroll', schedule, true);
      addEventListener('resize', schedule);
      addEventListener('load', schedule);
      extract();
    })();
    """#

    /// A small, deterministic landing page with known ids and a spread of roles — links, buttons,
    /// an input, headings, an `aria-label`d button, and unlabeled buttons that exercise the generated
    /// selector path. Loaded from a string so nothing depends on resource bundling.
    static let demoPage = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      * { box-sizing: border-box; }
      body { margin: 0; font-family: -apple-system, system-ui, sans-serif; background: #f5f5f7; color: #1d1d1f; }
      header { padding: 22px 40px; display: flex; gap: 28px; align-items: center; border-bottom: 1px solid #d2d2d7; }
      nav a { margin-right: 22px; color: #0066cc; text-decoration: none; font-size: 18px; }
      main { padding: 48px 40px; max-width: 900px; margin: 0 auto; }
      h1 { font-size: 46px; margin: 0 0 16px; }
      p.lede { font-size: 21px; color: #6e6e73; margin: 0 0 34px; }
      .cta-row { display: flex; gap: 18px; margin-bottom: 44px; }
      button { font-size: 19px; padding: 15px 30px; border-radius: 12px; border: none; cursor: pointer; }
      #cta-primary { background: #0066cc; color: white; }
      #cta-secondary { background: #e3e3e8; color: #1d1d1f; }
      .card { background: white; border: 1px solid #d2d2d7; border-radius: 16px; padding: 30px; margin-bottom: 24px; }
      .card h2 { margin: 0 0 14px; font-size: 28px; }
      input { font-size: 18px; padding: 13px 16px; border-radius: 10px; border: 1px solid #d2d2d7; width: 320px; margin-right: 12px; }
      footer { padding: 34px 40px; color: #86868b; font-size: 15px; }
    </style>
    </head>
    <body>
      <header>
        <strong style="font-size:21px">Vergance</strong>
        <nav>
          <a id="nav-features" href="#features">Features</a>
          <a id="nav-pricing" href="#pricing">Pricing</a>
          <a id="nav-docs" href="#docs">Docs</a>
        </nav>
      </header>
      <main>
        <h1 id="headline">Look. Speak. Done.</h1>
        <p class="lede">Point with your eyes, confirm with your voice.</p>
        <div class="cta-row">
          <button id="cta-primary">Get started</button>
          <button id="cta-secondary">Learn more</button>
        </div>
        <div class="card">
          <h2 id="features">Features</h2>
          <p>Gaze-driven targeting fused with push-to-talk.</p>
          <button aria-label="Watch the product demo video">Watch demo</button>
        </div>
        <div class="card">
          <h2 id="pricing">Pricing</h2>
          <input id="email" type="email" aria-label="Email address" placeholder="you@example.com">
          <button>Notify me</button>
        </div>
      </main>
      <footer>© 2026 Vergance</footer>
    </body>
    </html>
    """
}
