import Foundation

/// A detected fixation: gaze dwelling within a small spatial window.
public struct Fixation: Sendable, Equatable, Codable {
    public var start: TimeInterval
    public var end: TimeInterval
    public var centroid: ScreenPoint
    public var durationMs: Double { (end - start) * 1000 }

    public init(start: TimeInterval, end: TimeInterval, centroid: ScreenPoint) {
        self.start = start
        self.end = end
        self.centroid = centroid
    }
}

/// Streaming dispersion-threshold (I-DT) fixation detector.
///
/// Feed points in time order; it emits a ``Fixation`` when a dwell within `maxDispersion`
/// lasting at least `minDuration` ends (i.e. when the gaze leaves the cluster).
public final class FixationDetector {
    public var maxDispersion: Double   // normalized units, summed over x + y
    public var minDuration: TimeInterval

    private struct Stamped {
        var p: ScreenPoint
        var t: TimeInterval
    }
    private var window: [Stamped] = []

    public init(maxDispersion: Double = 0.05, minDuration: TimeInterval = 0.15) {
        self.maxDispersion = maxDispersion
        self.minDuration = minDuration
    }

    public func reset() { window.removeAll() }

    /// Add a point; returns a ``Fixation`` if one just completed at this point.
    public func add(_ p: ScreenPoint, at t: TimeInterval) -> Fixation? {
        window.append(Stamped(p: p, t: t))
        if dispersion(window) <= maxDispersion { return nil }
        // The new point breaks the cluster — close the fixation on everything before it.
        let cluster = Array(window.dropLast())
        window = [Stamped(p: p, t: t)]
        return fixation(from: cluster)
    }

    /// Flush any in-progress fixation. Call at session end.
    public func flush() -> Fixation? {
        let cluster = window
        window.removeAll()
        return fixation(from: cluster)
    }

    private func fixation(from cluster: [Stamped]) -> Fixation? {
        guard let first = cluster.first, let last = cluster.last else { return nil }
        guard last.t - first.t >= minDuration else { return nil }
        let cx = cluster.reduce(0) { $0 + $1.p.x } / Double(cluster.count)
        let cy = cluster.reduce(0) { $0 + $1.p.y } / Double(cluster.count)
        return Fixation(start: first.t, end: last.t, centroid: ScreenPoint(x: cx, y: cy))
    }

    private func dispersion(_ pts: [Stamped]) -> Double {
        guard !pts.isEmpty else { return 0 }
        let xs = pts.map(\.p.x)
        let ys = pts.map(\.p.y)
        return (xs.max()! - xs.min()!) + (ys.max()! - ys.min()!)
    }
}
