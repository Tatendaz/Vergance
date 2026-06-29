import Foundation

/// A recognized speech result with the exact capture window it was spoken in.
///
/// Produced by the platform speech recognizer (`Speech.framework` lives in the app target); kept
/// as a plain value type here so fusion stays platform-agnostic and headless-testable.
public struct SpeechResult: Sendable, Equatable {
    public var text: String
    public var confidence: Double
    public var tStart: TimeInterval
    public var tEnd: TimeInterval

    public init(text: String, confidence: Double, tStart: TimeInterval, tEnd: TimeInterval) {
        self.text = text
        self.confidence = confidence
        self.tStart = tStart
        self.tEnd = tEnd
    }
}

/// Fuses a recognized speech window with the fixation stream and mouth-openness samples into a
/// single Claude-facing ``Utterance`` — the deixis-resolving core object ("make *this* bigger").
///
/// Until element resolution lands (Phase 5), each ``GazeTarget`` carries a geometric region id (a
/// 3×3 screen cell) rather than a named element. The ranking and `primaryTarget` heuristic are
/// unchanged when real element ids arrive.
public struct UtteranceFuser: Sendable {
    /// How a fixation sits relative to the speech window.
    public enum Overlap: String, Sendable {
        case during     // its dwell interval intersects the window
        case leading    // ended just before the window, within `leadMargin`
        case trailing   // started just after the window, within `trailMargin`
    }

    // Tunable like the FixationDetector thresholds; pinned by tests.
    public var leadMargin: TimeInterval     // a glance just before speaking still counts
    public var trailMargin: TimeInterval
    public var dwellWeightPerSecond: Double // how much a second of dwell adds to the score
    public var primaryMargin: Double        // top must beat the runner-up by this score gap

    private static let classWeight: [Overlap: Double] = [.during: 1.0, .leading: 0.5, .trailing: 0.4]

    public init(
        leadMargin: TimeInterval = 0.4,
        trailMargin: TimeInterval = 0.3,
        dwellWeightPerSecond: Double = 0.5,
        primaryMargin: Double = 0.15
    ) {
        self.leadMargin = leadMargin
        self.trailMargin = trailMargin
        self.dwellWeightPerSecond = dwellWeightPerSecond
        self.primaryMargin = primaryMargin
    }

    /// Classify a fixation against `[windowStart, windowEnd]`, or nil if it falls outside the margins.
    public func overlap(of fixation: Fixation, windowStart: TimeInterval, windowEnd: TimeInterval) -> Overlap? {
        if fixation.start <= windowEnd && fixation.end >= windowStart { return .during }
        if fixation.end < windowStart, windowStart - fixation.end <= leadMargin { return .leading }
        if fixation.start > windowEnd, fixation.start - windowEnd <= trailMargin { return .trailing }
        return nil
    }

    /// Build the ``Utterance`` from a speech window, the fixation stream, and the mouth samples.
    public func fuse(speech: SpeechResult, fixations: [Fixation], mouthSamples: [MouthSample]) -> Utterance {
        let scored: [(target: GazeTarget, score: Double)] = fixations.compactMap { fix in
            guard let ov = overlap(of: fix, windowStart: speech.tStart, windowEnd: speech.tEnd) else { return nil }
            let score = (Self.classWeight[ov] ?? 0) + dwellWeightPerSecond * (fix.durationMs / 1000)
            let target = GazeTarget(
                id: Self.regionID(for: fix.centroid),
                role: "region",
                dwellMs: fix.durationMs,
                overlap: ov.rawValue
            )
            return (target, score)
        }
        .sorted { $0.score > $1.score }

        // Expose each target's confidence as its share of the total score — interpretable and
        // monotonic with rank, without faking a calibrated probability.
        let total = scored.reduce(0) { $0 + $1.score }
        let gazeTargets: [GazeTarget] = scored.map { item in
            var t = item.target
            t.confidence = total > 0 ? item.score / total : nil
            return t
        }

        let primaryTarget: String? = {
            guard let top = scored.first else { return nil }       // no gaze → text-only utterance
            guard scored.count > 1 else { return top.target.id }   // single candidate is unambiguous
            return top.score - scored[1].score >= primaryMargin ? top.target.id : nil
        }()

        return Utterance(
            tStart: speech.tStart,
            tEnd: speech.tEnd,
            text: speech.text,
            speechConfidence: speech.confidence,
            gazeTargets: gazeTargets,
            primaryTarget: primaryTarget,
            voiceActivity: VoiceActivity(from: mouthSamples, in: speech.tStart...speech.tEnd)
        )
    }

    /// Geometric placeholder id: the 3×3 screen cell ("r{row}c{col}") the centroid lands in,
    /// origin top-left. Replaced by real element ids in Phase 5 without changing fusion.
    static func regionID(for p: ScreenPoint) -> String {
        func cell(_ v: Double) -> Int { min(2, max(0, Int(v * 3))) }
        return "r\(cell(p.y))c\(cell(p.x))"
    }
}
