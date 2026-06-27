import XCTest
@testable import GazeKit

final class FaceLandmarksTests: XCTestCase {
    private func eye(inner: (Double, Double), outer: (Double, Double), pupil: (Double, Double)) -> EyeLandmarks {
        EyeLandmarks(
            innerCorner: Point2D(x: inner.0, y: inner.1),
            outerCorner: Point2D(x: outer.0, y: outer.1),
            pupil: Point2D(x: pupil.0, y: pupil.1)
        )
    }

    func testPupilCenteredGivesZeroOffset() {
        let left = eye(inner: (0.3, 0.5), outer: (0.4, 0.5), pupil: (0.35, 0.5))
        let right = eye(inner: (0.6, 0.5), outer: (0.7, 0.5), pupil: (0.65, 0.5))
        let f = FaceLandmarks(leftEye: left, rightEye: right, outerLips: [], headPose: .init())
        let g = GazeFeatures.pupilOffset(f)
        XCTAssertEqual(g.gx, 0, accuracy: 1e-9)
        XCTAssertEqual(g.gy, 0, accuracy: 1e-9)
    }

    func testPupilShiftScalesWithEyeWidth() {
        // eye width 0.1; pupil at the outer corner → offset of +0.5 eye-widths
        let left = eye(inner: (0.3, 0.5), outer: (0.4, 0.5), pupil: (0.40, 0.5))
        let right = eye(inner: (0.6, 0.5), outer: (0.7, 0.5), pupil: (0.70, 0.5))
        let f = FaceLandmarks(leftEye: left, rightEye: right, outerLips: [], headPose: .init())
        let g = GazeFeatures.pupilOffset(f)
        XCTAssertEqual(g.gx, 0.5, accuracy: 1e-9)
        XCTAssertEqual(g.gy, 0, accuracy: 1e-9)
    }

    func testMouthAspectRatio() {
        // inner-lip contour: upper pair at y=0.48, lower pair at y=0.52, width 0.2.
        // gap 0.04 / width 0.2 → MAR 0.2
        let innerLips = [
            Point2D(x: 0.4, y: 0.48), Point2D(x: 0.6, y: 0.48),
            Point2D(x: 0.4, y: 0.52), Point2D(x: 0.6, y: 0.52),
        ]
        XCTAssertEqual(GazeFeatures.mouthAspectRatio(innerLips), 0.2, accuracy: 1e-9)
        XCTAssertEqual(GazeFeatures.mouthAspectRatio([]), 0, accuracy: 1e-9)
    }

    func testSampleAssemblesGazeSample() {
        let left = eye(inner: (0.3, 0.5), outer: (0.4, 0.5), pupil: (0.35, 0.5))
        let right = eye(inner: (0.6, 0.5), outer: (0.7, 0.5), pupil: (0.65, 0.5))
        let innerLips = [
            Point2D(x: 0.4, y: 0.48), Point2D(x: 0.6, y: 0.48),
            Point2D(x: 0.4, y: 0.52), Point2D(x: 0.6, y: 0.52),
        ]
        let f = FaceLandmarks(
            leftEye: left, rightEye: right, outerLips: [], innerLips: innerLips,
            headPose: HeadPose(yaw: 0.1, pitch: 0.2, roll: 0.3)
        )
        let s = GazeFeatures.sample(f, t: 1.5)
        XCTAssertEqual(s.gazeFeatures.count, 2)
        XCTAssertEqual(s.t, 1.5, accuracy: 1e-9)
        XCTAssertEqual(s.mouth.openness, 0.2, accuracy: 1e-9)
        XCTAssertEqual(s.headPose.yaw, 0.1, accuracy: 1e-9)
    }
}
