import Foundation

/// Head orientation in radians, sensor-agnostic.
public struct HeadPose: Sendable, Equatable, Codable {
    public var yaw: Double
    public var pitch: Double
    public var roll: Double
    public init(yaw: Double = 0, pitch: Double = 0, roll: Double = 0) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }
}

/// Mouth state used for voice-activity and emphasis — never for lipreading.
public struct MouthSignal: Sendable, Equatable, Codable {
    /// 0 = closed, 1 = wide open. From ARKit `jawOpen` or a webcam mouth-aspect-ratio proxy.
    public var openness: Double
    public init(openness: Double = 0) { self.openness = openness }
}

/// One frame of perception, produced by any ``GazeSensor``.
///
/// `gazeFeatures` are raw, pre-calibration, and sensor-specific (webcam pupil offsets vs
/// ARKit `lookAtPoint`). The calibration model maps them to screen coordinates.
public struct GazeSample: Sendable, Equatable {
    public var t: TimeInterval
    public var gazeFeatures: [Double]
    public var headPose: HeadPose
    public var mouth: MouthSignal
    public var confidence: Double

    public init(
        t: TimeInterval,
        gazeFeatures: [Double],
        headPose: HeadPose = .init(),
        mouth: MouthSignal = .init(),
        confidence: Double = 1
    ) {
        self.t = t
        self.gazeFeatures = gazeFeatures
        self.headPose = headPose
        self.mouth = mouth
        self.confidence = confidence
    }
}

/// A point in normalized screen space: origin top-left, each axis in [0, 1].
public struct ScreenPoint: Sendable, Equatable, Codable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
