import Foundation

/// A timestamped mouth-openness reading — one per face frame — feeding voice-activity.
///
/// `openness` is the mouth-aspect-ratio proxy (see ``GazeFeatures/mouthAspectRatio(_:)``), the
/// same value already carried on every ``GazeSample`` as ``MouthSignal/openness``. Audio supplies
/// the words; these samples are the lips' contribution — timing and emphasis only, never lipreading.
public struct MouthSample: Sendable, Equatable {
    public var t: TimeInterval
    public var openness: Double

    public init(t: TimeInterval, openness: Double) {
        self.t = t
        self.openness = openness
    }

    /// Lift the mouth reading off a ``GazeSample`` frame.
    public init(_ sample: GazeSample) {
        self.init(t: sample.t, openness: sample.mouth.openness)
    }
}

public extension VoiceActivity {
    /// Reduce the mouth-openness samples whose timestamps fall in `window` to the mean and peak
    /// openness over that window. Frames with no sample simply aren't present, so gaps don't skew
    /// the result; an empty window reduces to zeros.
    init(from samples: [MouthSample], in window: ClosedRange<TimeInterval>) {
        let inWindow = samples.filter { window.contains($0.t) }
        guard !inWindow.isEmpty else {
            self.init(jawOpenMean: 0, peak: 0)
            return
        }
        let mean = inWindow.reduce(0) { $0 + $1.openness } / Double(inWindow.count)
        let peak = inWindow.map(\.openness).max() ?? 0
        self.init(jawOpenMean: mean, peak: peak)
    }
}
