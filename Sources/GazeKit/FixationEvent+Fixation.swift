import Foundation

public extension FixationEvent {
    /// Build a Claude-facing ``FixationEvent`` from a geometric ``Fixation`` (the
    /// `FixationDetector` output), optionally resolved to a target element. The
    /// element-resolution step lands in a later phase; until then `target` is nil.
    init(_ fixation: Fixation, target: GazeTarget? = nil, confidence: Double = 1) {
        self.init(
            tStart: fixation.start,
            tEnd: fixation.end,
            point: fixation.centroid,
            target: target,
            confidence: confidence
        )
    }
}
