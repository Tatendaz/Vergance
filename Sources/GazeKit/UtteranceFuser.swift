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
/// Each ``GazeTarget`` is resolved against the active surface's ``ElementMap`` to a named element
/// (`id`/`role`/`label`); a fixation that hits no element falls back to a geometric region id, so
/// an empty map reproduces the pre-element-resolution behavior. Ranking and `primaryTarget` are
/// unchanged by resolution — only target identity changes.
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

    /// Lower rank = stronger overlap; used to keep the best class when aggregating a region.
    private static func classRank(_ o: Overlap) -> Int {
        switch o {
        case .during: return 0
        case .leading: return 1
        case .trailing: return 2
        }
    }

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

    /// Build the ``Utterance`` from a speech window, the fixation stream, the mouth samples, and the
    /// active surface's ``ElementMap``.
    ///
    /// Overlapping fixations are resolved against `elements` (named element, else a geometric region
    /// fallback) and grouped by resolved target id first, so several glances at the same element
    /// aggregate into one target (summed dwell, strongest overlap) rather than competing as
    /// duplicates — otherwise the primary margin could read as a tie against the element itself.
    public func fuse(
        speech: SpeechResult,
        fixations: [Fixation],
        mouthSamples: [MouthSample],
        elements: ElementMap = ElementMap()
    ) -> Utterance {
        struct Aggregate { var role: String?; var label: String?; var overlap: Overlap; var dwellMs: Double }
        var byID: [String: Aggregate] = [:]
        var order: [String] = []   // first-seen order, for a deterministic tiebreak
        for fix in fixations {
            guard let ov = overlap(of: fix, windowStart: speech.tStart, windowEnd: speech.tEnd) else { continue }
            let resolved = elements.resolve(fix.centroid)   // named element id, else region-id fallback
            let id = resolved.id
            if var agg = byID[id] {
                agg.dwellMs += fix.durationMs
                if Self.classRank(ov) < Self.classRank(agg.overlap) { agg.overlap = ov }
                byID[id] = agg
            } else {
                byID[id] = Aggregate(role: resolved.role, label: resolved.label, overlap: ov, dwellMs: fix.durationMs)
                order.append(id)
            }
        }

        func score(_ a: Aggregate) -> Double {
            (Self.classWeight[a.overlap] ?? 0) + dwellWeightPerSecond * (a.dwellMs / 1000)
        }
        let ranked = order.map { (id: $0, agg: byID[$0]!) }
            .sorted { lhs, rhs in
                let ls = score(lhs.agg), rs = score(rhs.agg)
                return ls == rs ? lhs.id < rhs.id : ls > rs   // deterministic on ties
            }

        // Expose each target's confidence as its share of the total score — interpretable and
        // monotonic with rank, without faking a calibrated probability.
        let total = ranked.reduce(0.0) { $0 + score($1.agg) }
        let gazeTargets: [GazeTarget] = ranked.map { item in
            GazeTarget(
                id: item.id,
                role: item.agg.role,
                label: item.agg.label,
                dwellMs: item.agg.dwellMs,
                overlap: item.agg.overlap.rawValue,
                confidence: total > 0 ? score(item.agg) / total : nil
            )
        }

        let primaryTarget: String? = {
            guard let top = ranked.first else { return nil }        // no gaze → text-only utterance
            guard ranked.count > 1 else { return top.id }           // single candidate is unambiguous
            return score(top.agg) - score(ranked[1].agg) >= primaryMargin ? top.id : nil
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

    /// Geometric region id: the 3×3 screen cell ("r{row}c{col}") the centroid lands in, origin
    /// top-left. Used by ``ElementMap/resolve(_:dwellMs:overlap:confidence:)`` as the fallback when
    /// a gaze point hits no named element.
    static func regionID(for p: ScreenPoint) -> String {
        func cell(_ v: Double) -> Int { min(2, max(0, Int(v * 3))) }
        return "r\(cell(p.y))c\(cell(p.x))"
    }
}
