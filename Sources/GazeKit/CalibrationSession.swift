import Foundation

/// Standard calibration target layouts in normalized screen space (origin top-left).
public enum CalibrationTargets {
    /// 9 points: corners, edge midpoints, and center. Sized for the quadratic fit.
    public static let ninePoint: [ScreenPoint] = [
        ScreenPoint(x: 0.1, y: 0.1), ScreenPoint(x: 0.5, y: 0.1), ScreenPoint(x: 0.9, y: 0.1),
        ScreenPoint(x: 0.1, y: 0.5), ScreenPoint(x: 0.5, y: 0.5), ScreenPoint(x: 0.9, y: 0.5),
        ScreenPoint(x: 0.1, y: 0.9), ScreenPoint(x: 0.5, y: 0.9), ScreenPoint(x: 0.9, y: 0.9),
    ]
}

/// Collects per-target gaze-feature samples during a calibration run and fits a
/// ``CalibrationModel``.
///
/// Per target the UI shows a dot and captures ~30 frames; the first ~10 are discarded
/// (the eyes are still saccading to the dot) and the rest are reduced by **median** —
/// robust to blinks and tracking dropouts. The per-target medians become the
/// correspondences fed to ``CalibrationFitter``.
public struct CalibrationSession {
    public let targets: [ScreenPoint]
    private var raw: [[(gx: Double, gy: Double)]]

    public init(targets: [ScreenPoint] = CalibrationTargets.ninePoint) {
        self.targets = targets
        self.raw = Array(repeating: [], count: targets.count)
    }

    /// Number of raw samples captured for a target so far.
    public func sampleCount(targetIndex i: Int) -> Int {
        raw.indices.contains(i) ? raw[i].count : 0
    }

    /// Record one gaze-feature sample for the target currently being shown.
    public mutating func add(targetIndex i: Int, gx: Double, gy: Double) {
        guard raw.indices.contains(i) else { return }
        raw[i].append((gx, gy))
    }

    /// Per-target median `(gx, gy)` after discarding the first `discardFirst` settling
    /// frames. An entry is `nil` if a target has no usable samples left.
    func medians(discardFirst: Int) -> [(gx: Double, gy: Double)?] {
        raw.map { samples in
            let kept = samples.count > discardFirst ? Array(samples.dropFirst(discardFirst)) : samples
            guard !kept.isEmpty else { return nil }
            return (gx: medianOf(kept.map { $0.gx }), gy: medianOf(kept.map { $0.gy }))
        }
    }

    /// Fit a ``CalibrationModel`` from the per-target medians and report the RMS error in
    /// **pixels** over the calibration targets. Returns `nil` if any target lacks usable
    /// samples or the fit is under-determined.
    public func fit(
        discardFirst: Int = 10,
        ridge: Double = 1e-3,
        screenWidth: Int,
        screenHeight: Int
    ) -> (model: CalibrationModel, rmsErrorPx: Double)? {
        let meds = medians(discardFirst: discardFirst)
        var fitter = CalibrationFitter(ridge: ridge)
        for (i, m) in meds.enumerated() {
            guard let m else { return nil }
            fitter.add(.init(gx: m.gx, gy: m.gy, sx: targets[i].x, sy: targets[i].y))
        }
        guard let model = fitter.fit() else { return nil }

        var sse = 0.0
        for (i, m) in meds.enumerated() {
            guard let m else { return nil }
            let p = model.map(m.gx, m.gy)
            let dx = (p.x - targets[i].x) * Double(screenWidth)
            let dy = (p.y - targets[i].y) * Double(screenHeight)
            sse += dx * dx + dy * dy
        }
        let rms = (sse / Double(meds.count)).squareRoot()
        return (model, rms)
    }
}

/// Median of a list (via a sorted copy). Returns 0 for empty input.
func medianOf(_ xs: [Double]) -> Double {
    guard !xs.isEmpty else { return 0 }
    let s = xs.sorted()
    let n = s.count
    return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
}
