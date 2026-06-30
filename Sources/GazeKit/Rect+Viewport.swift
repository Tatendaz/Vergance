import Foundation

public extension Rect {
    /// Place a viewport-pixel rect into this normalized surface frame.
    ///
    /// `self` is the web view's on-surface frame (normalized `[0, 1]`, origin top-left); the
    /// `x`/`y`/`width`/`height` are a DOM element's `getBoundingClientRect` in viewport CSS pixels —
    /// viewport-relative, with scroll already applied. The result is the element's rect in the same
    /// normalized space as the gaze cursor, so it can populate an ``ElementMap`` that resolves
    /// against gaze points. A degenerate (≤ 0) viewport yields a zero-size rect at the frame origin.
    func place(
        x: Double, y: Double, width: Double, height: Double,
        viewportWidth: Double, viewportHeight: Double
    ) -> Rect {
        guard viewportWidth > 0, viewportHeight > 0 else { return Rect(x: self.x, y: self.y, w: 0, h: 0) }
        return Rect(
            x: self.x + (x / viewportWidth) * self.w,
            y: self.y + (y / viewportHeight) * self.h,
            w: (width / viewportWidth) * self.w,
            h: (height / viewportHeight) * self.h
        )
    }
}
