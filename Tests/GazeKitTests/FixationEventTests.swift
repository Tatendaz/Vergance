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

    func testResolvesTargetThroughElementMap() {
        let cta = Element(
            id: "cta-primary", role: "button", label: "Sign up",
            rect: Rect(x: 0.4, y: 0.4, w: 0.2, h: 0.2)
        )
        let map = ElementMap(elements: [cta])
        let event = FixationEvent(
            Fixation(start: 1.0, end: 1.6, centroid: ScreenPoint(x: 0.5, y: 0.5)),
            resolvedBy: map, confidence: 0.9
        )
        XCTAssertEqual(event.target?.id, "cta-primary")
        XCTAssertEqual(event.target?.label, "Sign up")
        XCTAssertEqual(event.target?.dwellMs ?? 0, 600, accuracy: 1e-9)   // fixation duration
    }

    func testResolvesToRegionFallbackOnMiss() {
        let event = FixationEvent(
            Fixation(start: 1.0, end: 1.6, centroid: ScreenPoint(x: 0.1, y: 0.1)),
            resolvedBy: ElementMap(), confidence: 1
        )
        XCTAssertEqual(event.target?.id, "r0c0")
        XCTAssertEqual(event.target?.role, "region")
    }
}
