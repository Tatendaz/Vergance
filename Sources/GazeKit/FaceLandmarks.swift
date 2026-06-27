import Foundation

/// A 2-D point normalized to the image: each axis in [0, 1], origin top-left.
public struct Point2D: Sendable, Equatable, Codable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// One eye's landmarks, in normalized image coordinates (origin top-left).
public struct EyeLandmarks: Sendable, Equatable {
    public var innerCorner: Point2D
    public var outerCorner: Point2D
    public var pupil: Point2D
    public init(innerCorner: Point2D, outerCorner: Point2D, pupil: Point2D) {
        self.innerCorner = innerCorner
        self.outerCorner = outerCorner
        self.pupil = pupil
    }
}

/// Face landmarks extracted from one frame — by Vision on macOS or ARKit on iOS.
/// All points are normalized image coordinates, origin top-left.
public struct FaceLandmarks: Sendable, Equatable {
    public var leftEye: EyeLandmarks
    public var rightEye: EyeLandmarks
    public var outerLips: [Point2D]      // outer-lip contour (for the overlay)
    public var innerLips: [Point2D]      // inner-lip contour (drives mouth-opening / MAR)
    public var headPose: HeadPose
    public init(
        leftEye: EyeLandmarks,
        rightEye: EyeLandmarks,
        outerLips: [Point2D],
        innerLips: [Point2D] = [],
        headPose: HeadPose
    ) {
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.outerLips = outerLips
        self.innerLips = innerLips
        self.headPose = headPose
    }
}

/// Pure feature math turning raw landmarks into the sensor-agnostic ``GazeSample``.
/// This is the seam between platform sensors (Vision / ARKit) and the calibration
/// pipeline — kept here so it stays headless-testable.
public enum GazeFeatures {
    /// Mean normalized pupil offset from eye center across both eyes.
    /// Returns `(gx, gy)` — the raw feature pair consumed by ``CalibrationModel/map(_:_:)``.
    /// `(0, 0)` means both pupils sit at their eye centers (gaze straight ahead).
    public static func pupilOffset(_ f: FaceLandmarks) -> (gx: Double, gy: Double) {
        let l = eyeOffset(f.leftEye)
        let r = eyeOffset(f.rightEye)
        return (gx: (l.x + r.x) / 2, gy: (l.y + r.y) / 2)
    }

    /// Pupil offset from one eye's center, normalized by that eye's corner-to-corner width.
    static func eyeOffset(_ e: EyeLandmarks) -> (x: Double, y: Double) {
        let cx = (e.innerCorner.x + e.outerCorner.x) / 2
        let cy = (e.innerCorner.y + e.outerCorner.y) / 2
        let dx = e.outerCorner.x - e.innerCorner.x
        let dy = e.outerCorner.y - e.innerCorner.y
        let width = (dx * dx + dy * dy).squareRoot()
        guard width > 1e-9 else { return (0, 0) }
        return (x: (e.pupil.x - cx) / width, y: (e.pupil.y - cy) / width)
    }

    /// Mouth-aspect-ratio from the inner-lip contour: the vertical gap between the
    /// mean upper and mean lower inner-lip point, normalized by mouth width. This
    /// measures the actual opening (≈0 with the mouth closed) rather than the outer-lip
    /// extent, so it isn't driven by lip thickness. Used for voice-activity and
    /// emphasis, never lipreading. Returns 0 for degenerate input.
    public static func mouthAspectRatio(_ innerLips: [Point2D]) -> Double {
        guard innerLips.count >= 4 else { return 0 }
        let meanY = innerLips.reduce(0) { $0 + $1.y } / Double(innerLips.count)
        let upper = innerLips.filter { $0.y < meanY }   // top-left origin: smaller y is higher
        let lower = innerLips.filter { $0.y >= meanY }
        guard !upper.isEmpty, !lower.isEmpty else { return 0 }
        let upperY = upper.reduce(0) { $0 + $1.y } / Double(upper.count)
        let lowerY = lower.reduce(0) { $0 + $1.y } / Double(lower.count)
        let xs = innerLips.map(\.x)
        let width = xs.max()! - xs.min()!
        guard width > 1e-9 else { return 0 }
        return (lowerY - upperY) / width
    }

    /// Assemble a ``GazeSample`` from one frame's landmarks: pupil-offset gaze features,
    /// head pose, and mouth openness.
    public static func sample(_ f: FaceLandmarks, t: TimeInterval, confidence: Double = 1) -> GazeSample {
        let (gx, gy) = pupilOffset(f)
        return GazeSample(
            t: t,
            gazeFeatures: [gx, gy],
            headPose: f.headPose,
            mouth: MouthSignal(openness: mouthAspectRatio(f.innerLips)),
            confidence: confidence
        )
    }
}
