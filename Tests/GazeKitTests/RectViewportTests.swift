import XCTest
@testable import GazeKit

final class RectViewportTests: XCTestCase {
    private let fullSurface = Rect(x: 0, y: 0, w: 1, h: 1)

    func testFullViewportRectFillsFullSurface() {
        let r = fullSurface.place(x: 0, y: 0, width: 1000, height: 800,
                                  viewportWidth: 1000, viewportHeight: 800)
        XCTAssertEqual(r, Rect(x: 0, y: 0, w: 1, h: 1))
    }

    func testCenteredRectMapsToSurfaceCentre() {
        let r = fullSurface.place(x: 500, y: 400, width: 100, height: 80,
                                  viewportWidth: 1000, viewportHeight: 800)
        XCTAssertEqual(r, Rect(x: 0.5, y: 0.5, w: 0.1, h: 0.1))
    }

    func testSubFrameOffsetsAndScales() {
        // Web view occupies the right half of the surface.
        let rightHalf = Rect(x: 0.5, y: 0, w: 0.5, h: 1)
        let r = rightHalf.place(x: 250, y: 200, width: 500, height: 400,
                                viewportWidth: 1000, viewportHeight: 800)
        XCTAssertEqual(r.x, 0.625, accuracy: 1e-9)   // 0.5 + (250/1000)*0.5
        XCTAssertEqual(r.y, 0.25, accuracy: 1e-9)    // 0   + (200/800)*1
        XCTAssertEqual(r.w, 0.25, accuracy: 1e-9)    // (500/1000)*0.5
        XCTAssertEqual(r.h, 0.5, accuracy: 1e-9)     // (400/800)*1
    }

    func testViewportOriginMapsToFrameOrigin() {
        let frame = Rect(x: 0.2, y: 0.3, w: 0.4, h: 0.4)
        let r = frame.place(x: 0, y: 0, width: 10, height: 10,
                            viewportWidth: 1280, viewportHeight: 720)
        XCTAssertEqual(r.x, 0.2, accuracy: 1e-9)
        XCTAssertEqual(r.y, 0.3, accuracy: 1e-9)
    }

    func testDegenerateViewportIsSafe() {
        let r = fullSurface.place(x: 100, y: 100, width: 50, height: 50,
                                  viewportWidth: 0, viewportHeight: 0)
        XCTAssertEqual(r, Rect(x: 0, y: 0, w: 0, h: 0))
    }

    func testResolvesThroughElementMap() {
        // The placed rect must hit-test correctly against a gaze point in the same space.
        let frame = Rect(x: 0, y: 0, w: 1, h: 1)
        let rect = frame.place(x: 400, y: 300, width: 200, height: 100,
                               viewportWidth: 1000, viewportHeight: 1000)   // → (0.4,0.3,0.2,0.1)
        let map = ElementMap(elements: [Element(id: "cta-primary", role: "button", rect: rect)])
        XCTAssertEqual(map.resolve(ScreenPoint(x: 0.5, y: 0.35)).id, "cta-primary")
        XCTAssertEqual(map.resolve(ScreenPoint(x: 0.9, y: 0.9)).role, "region")   // outside → fallback
    }
}
