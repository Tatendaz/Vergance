import Foundation

public extension FixationEvent {
    /// Build a Claude-facing ``FixationEvent`` from a geometric ``Fixation`` (the
    /// `FixationDetector` output), optionally resolved to a target element. Pass a non-nil
    /// `target` to attach one, or use ``init(_:resolvedBy:confidence:)`` to resolve it from an
    /// ``ElementMap``.
    init(_ fixation: Fixation, target: GazeTarget? = nil, confidence: Double = 1) {
        self.init(
            tStart: fixation.start,
            tEnd: fixation.end,
            point: fixation.centroid,
            target: target,
            confidence: confidence
        )
    }

    /// Build a ``FixationEvent`` whose `target` is resolved from the fixation centroid against the
    /// active surface's ``ElementMap`` — a named element when one is hit, else a geometric region
    /// fallback. Uses the same ``ElementMap/resolve(_:dwellMs:overlap:confidence:)`` path as the
    /// utterance fuser, so fixation events and utterances agree on element identity.
    init(_ fixation: Fixation, resolvedBy elements: ElementMap, confidence: Double = 1) {
        self.init(
            fixation,
            target: elements.resolve(fixation.centroid, dwellMs: fixation.durationMs),
            confidence: confidence
        )
    }
}
