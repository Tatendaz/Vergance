import XCTest
@testable import GazeKit

final class HeadPoseDriftTests: XCTestCase {
    func testZeroDistanceToSelf() {
        let pose = HeadPose(yaw: 0.1, pitch: -0.2, roll: 0.05)
        XCTAssertEqual(pose.angularDistance(to: pose), 0, accuracy: 1e-12)
    }

    func testEuclideanOverAxesAndSymmetric() {
        let a = HeadPose(yaw: 0, pitch: 0, roll: 0)
        let b = HeadPose(yaw: 0.3, pitch: 0.4, roll: 0)   // 3-4-5 → 0.5
        XCTAssertEqual(a.angularDistance(to: b), 0.5, accuracy: 1e-9)
        XCTAssertEqual(b.angularDistance(to: a), 0.5, accuracy: 1e-9)
    }
}
