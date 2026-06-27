import XCTest
@testable import GazeKit

final class FixationEventTests: XCTestCase {
    func testFromFixation() {
        let fixation = Fixation(start: 1.0, end: 1.85, centroid: ScreenPoint(x: 0.3, y: 0.4))
        let event = FixationEvent(fixation, confidence: 0.9)
        XCTAssertEqual(event.type, .fixation)
        XCTAssertEqual(event.tStart, 1.0, accuracy: 1e-9)
        XCTAssertEqual(event.tEnd, 1.85, accuracy: 1e-9)
        XCTAssertEqual(event.point, ScreenPoint(x: 0.3, y: 0.4))
        XCTAssertEqual(event.confidence, 0.9, accuracy: 1e-9)
        XCTAssertNil(event.target)
    }

    func testRoundTripsThroughJSON() throws {
        let event = FixationEvent(
            Fixation(start: 2, end: 3, centroid: ScreenPoint(x: 0.5, y: 0.5)),
            target: GazeTarget(id: "cta", label: "Sign up"),
            confidence: 0.8
        )
        let data = try JSONEncoder().encode(event)
        XCTAssertEqual(try JSONDecoder().decode(FixationEvent.self, from: data), event)
    }
}
