import XCTest
@testable import GazeKit

final class CalibrationSessionTests: XCTestCase {
    func testNinePointTargets() {
        XCTAssertEqual(CalibrationTargets.ninePoint.count, 9)
        XCTAssertTrue(CalibrationTargets.ninePoint.contains(ScreenPoint(x: 0.5, y: 0.5)))
    }

    func testMedianOddEven() {
        XCTAssertEqual(medianOf([3, 1, 2]), 2, accuracy: 1e-9)
        XCTAssertEqual(medianOf([4, 1, 3, 2]), 2.5, accuracy: 1e-9)
        XCTAssertEqual(medianOf([]), 0, accuracy: 1e-9)
    }

    func testFitRecoversMappingWithLowRMS() {
        // A smooth, invertible ground-truth feature for each target.
        func feature(for t: ScreenPoint) -> (gx: Double, gy: Double) {
            (gx: t.x * 0.3 - 0.15, gy: t.y * 0.2 - 0.10)
        }
        var session = CalibrationSession()
        for (i, t) in CalibrationTargets.ninePoint.enumerated() {
            let f = feature(for: t)
            // Two saccade-settling outliers that discardFirst should drop, then clean samples.
            session.add(targetIndex: i, gx: f.gx + 5, gy: f.gy - 5)
            session.add(targetIndex: i, gx: f.gx - 5, gy: f.gy + 5)
            for _ in 0..<20 { session.add(targetIndex: i, gx: f.gx, gy: f.gy) }
        }
        guard let (model, rms) = session.fit(discardFirst: 2, screenWidth: 1000, screenHeight: 1000) else {
            return XCTFail("fit returned nil")
        }
        XCTAssertLessThan(rms, 5, "RMS px \(rms) too high")
        let c = feature(for: ScreenPoint(x: 0.5, y: 0.5))
        let p = model.map(c.gx, c.gy)
        XCTAssertEqual(p.x, 0.5, accuracy: 0.05)
        XCTAssertEqual(p.y, 0.5, accuracy: 0.05)
    }

    func testFitNilWhenATargetIsMissing() {
        var session = CalibrationSession()
        for i in 0..<8 {                       // fill 8 of 9 targets
            for _ in 0..<12 { session.add(targetIndex: i, gx: 0.1, gy: 0.1) }
        }
        XCTAssertNil(session.fit(discardFirst: 2, screenWidth: 800, screenHeight: 600))
    }
}
