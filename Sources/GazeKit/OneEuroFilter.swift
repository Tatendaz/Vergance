import Foundation

/// 1€ filter — adaptive low-pass smoothing (Casiez, Roussel & Vogel, 2012).
///
/// Low latency on fast motion, heavy smoothing when still. The standard choice for gaze
/// over a fixed EMA, which forces a single trade between jitter and lag.
public final class OneEuroFilter {
    public var minCutoff: Double
    public var beta: Double
    public var dCutoff: Double

    private var xPrev: Double?
    private var dxPrev: Double = 0
    private var tPrev: TimeInterval?

    public init(minCutoff: Double = 1.0, beta: Double = 0.007, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    public func reset() {
        xPrev = nil
        dxPrev = 0
        tPrev = nil
    }

    /// Filter one value sampled at monotonic time `t` (seconds).
    public func filter(_ x: Double, at t: TimeInterval) -> Double {
        defer { tPrev = t }
        guard let xp = xPrev, let tp = tPrev, t > tp else {
            xPrev = x
            dxPrev = 0
            return x
        }
        let dt = t - tp
        let dx = (x - xp) / dt
        let edx = Self.lowpass(dx, dxPrev, alpha: Self.alpha(cutoff: dCutoff, dt: dt))
        dxPrev = edx
        let cutoff = minCutoff + beta * abs(edx)
        let ex = Self.lowpass(x, xp, alpha: Self.alpha(cutoff: cutoff, dt: dt))
        xPrev = ex
        return ex
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1.0 / (2.0 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }

    private static func lowpass(_ x: Double, _ prev: Double, alpha: Double) -> Double {
        alpha * x + (1 - alpha) * prev
    }
}

/// Convenience 2-D wrapper for filtering gaze points.
public final class OneEuroFilter2D {
    private let fx: OneEuroFilter
    private let fy: OneEuroFilter

    public init(minCutoff: Double = 1.0, beta: Double = 0.007, dCutoff: Double = 1.0) {
        fx = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        fy = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
    }

    public func reset() {
        fx.reset()
        fy.reset()
    }

    public func filter(_ p: ScreenPoint, at t: TimeInterval) -> ScreenPoint {
        ScreenPoint(x: fx.filter(p.x, at: t), y: fy.filter(p.y, at: t))
    }
}
