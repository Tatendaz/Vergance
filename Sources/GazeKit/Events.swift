import Foundation

/// Discriminator for the Claude-facing event stream.
public enum EventType: String, Sendable, Codable {
    case sessionStart = "session_start"
    case fixation
    case utterance
    case sessionSummary = "session_summary"
}

/// An element the gaze resolved to, from the active surface's element tree.
public struct GazeTarget: Sendable, Equatable, Codable {
    public var id: String
    public var role: String?
    public var label: String?
    public var dwellMs: Double?
    public var overlap: String?      // "during" | "leading" | "trailing"
    public var confidence: Double?

    public init(
        id: String,
        role: String? = nil,
        label: String? = nil,
        dwellMs: Double? = nil,
        overlap: String? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.role = role
        self.label = label
        self.dwellMs = dwellMs
        self.overlap = overlap
        self.confidence = confidence
    }
}

/// Lips/jaw contribution: voice-activity and emphasis, never lipreading.
public struct VoiceActivity: Sendable, Equatable, Codable {
    public var jawOpenMean: Double
    public var peak: Double
    public init(jawOpenMean: Double, peak: Double) {
        self.jawOpenMean = jawOpenMean
        self.peak = peak
    }
}

/// Session header — tells Claude how much to trust spatial claims.
public struct SessionStart: Sendable, Equatable, Codable {
    public let type: EventType
    public var screenW: Int
    public var screenH: Int
    public var coordSystem: String
    public var calibrationPoints: Int
    public var calibrationModel: String
    public var rmsErrorPx: Double

    public init(
        screenW: Int,
        screenH: Int,
        coordSystem: String = "normalized, origin top-left",
        calibrationPoints: Int,
        calibrationModel: String = "quadratic",
        rmsErrorPx: Double
    ) {
        self.type = .sessionStart
        self.screenW = screenW
        self.screenH = screenH
        self.coordSystem = coordSystem
        self.calibrationPoints = calibrationPoints
        self.calibrationModel = calibrationModel
        self.rmsErrorPx = rmsErrorPx
    }
}

/// A fixation resolved to a design element.
public struct FixationEvent: Sendable, Equatable, Codable {
    public let type: EventType
    public var tStart: TimeInterval
    public var tEnd: TimeInterval
    public var point: ScreenPoint
    public var target: GazeTarget?
    public var confidence: Double

    public init(
        tStart: TimeInterval,
        tEnd: TimeInterval,
        point: ScreenPoint,
        target: GazeTarget? = nil,
        confidence: Double
    ) {
        self.type = .fixation
        self.tStart = tStart
        self.tEnd = tEnd
        self.point = point
        self.target = target
        self.confidence = confidence
    }
}

/// The gaze-resolved utterance — the object the whole product is built around.
///
/// `text` comes from speech (audio for words). `voiceActivity` is the lips contribution.
/// `gazeTargets` is ranked with confidences so Claude can disambiguate when the top two
/// are close, rather than being handed a single collapsed guess.
public struct Utterance: Sendable, Equatable, Codable {
    public let type: EventType
    public var tStart: TimeInterval
    public var tEnd: TimeInterval
    public var text: String
    public var speechConfidence: Double
    public var gazeTargets: [GazeTarget]
    public var primaryTarget: String?
    public var voiceActivity: VoiceActivity

    public init(
        tStart: TimeInterval,
        tEnd: TimeInterval,
        text: String,
        speechConfidence: Double,
        gazeTargets: [GazeTarget],
        primaryTarget: String?,
        voiceActivity: VoiceActivity
    ) {
        self.type = .utterance
        self.tStart = tStart
        self.tEnd = tEnd
        self.text = text
        self.speechConfidence = speechConfidence
        self.gazeTargets = gazeTargets
        self.primaryTarget = primaryTarget
        self.voiceActivity = voiceActivity
    }
}

/// Per-region aggregate for the post-hoc UX-analysis mode.
public struct RegionSummary: Sendable, Equatable, Codable {
    public var id: String
    public var fixations: Int
    public var totalDwellMs: Double
    public var firstFixationMs: Double?

    public init(id: String, fixations: Int, totalDwellMs: Double, firstFixationMs: Double?) {
        self.id = id
        self.fixations = fixations
        self.totalDwellMs = totalDwellMs
        self.firstFixationMs = firstFixationMs
    }
}

/// The heatmap / scanpath reduction over a recorded session.
public struct SessionSummary: Sendable, Equatable, Codable {
    public let type: EventType
    public var durationS: Double
    public var regions: [RegionSummary]
    public var scanpath: [String]

    public init(durationS: Double, regions: [RegionSummary], scanpath: [String]) {
        self.type = .sessionSummary
        self.durationS = durationS
        self.regions = regions
        self.scanpath = scanpath
    }
}
