import XCTest
@testable import GazeKit

final class CalibrationTests: XCTestCase {
    func testRecoversSmoothMapping() {
        var fitter = CalibrationFitter(ridge: 1e-6)
        func truthX(_ gx: Double, _ gy: Double) -> Double { 0.5 + 0.4 * gx - 0.1 * gy + 0.05 * gx * gy }
        func truthY(_ gx: Double, _ gy: Double) -> Double { 0.5 - 0.3 * gx + 0.2 * gy }
        let grid = [-1.0, 0.0, 1.0]
        for gx in grid {
            for gy in grid {
                fitter.add(.init(gx: gx, gy: gy, sx: truthX(gx, gy), sy: truthY(gx, gy)))
            }
        }
        guard let model = fitter.fit() else { return XCTFail("fit returned nil") }
        var sse = 0.0
        var n = 0
        for gx in grid {
            for gy in grid {
                let p = model.map(gx, gy)
                sse += pow(p.x - truthX(gx, gy), 2) + pow(p.y - truthY(gx, gy), 2)
                n += 2
            }
        }
        let rms = (sse / Double(n)).squareRoot()
        XCTAssertLessThan(rms, 1e-2, "RMS \(rms) too high")
    }

    func testUnderDeterminedReturnsNil() {
        var fitter = CalibrationFitter()
        fitter.add(.init(gx: 0, gy: 0, sx: 0, sy: 0))
        XCTAssertNil(fitter.fit())
    }
}

final class OneEuroFilterTests: XCTestCase {
    func testConstantPassesThrough() {
        let f = OneEuroFilter()
        var out = 0.0
        for i in 0..<10 { out = f.filter(0.5, at: Double(i) * 0.016) }
        XCTAssertEqual(out, 0.5, accuracy: 1e-9)
    }

    func testReducesJitter() {
        let f = OneEuroFilter(minCutoff: 0.5, beta: 0.0)   // pure low-pass, no speed adaptation
        var inputs: [Double] = []
        var outputs: [Double] = []
        for i in 0..<200 {
            let x = 0.5 + (i % 2 == 0 ? 0.1 : -0.1)
            inputs.append(x)
            outputs.append(f.filter(x, at: Double(i) * 0.016))
        }
        XCTAssertLessThan(variance(Array(outputs.suffix(100))), variance(Array(inputs.suffix(100))))
    }
}

final class FixationDetectorTests: XCTestCase {
    func testDetectsDwell() {
        let d = FixationDetector(maxDispersion: 0.05, minDuration: 0.15)
        var emitted: Fixation?
        for i in 0..<20 {
            let p = ScreenPoint(x: 0.5 + Double(i % 2) * 0.005, y: 0.5)
            if let f = d.add(p, at: Double(i) * 0.011) { emitted = f }
        }
        let fixation = emitted ?? d.flush()
        XCTAssertNotNil(fixation)
        XCTAssertGreaterThanOrEqual(fixation!.durationMs, 150)
        XCTAssertEqual(fixation!.centroid.x, 0.5, accuracy: 0.02)
    }

    func testScatterProducesNoFixation() {
        let d = FixationDetector(maxDispersion: 0.02, minDuration: 0.15)
        var any = false
        let pts = [(0.1, 0.1), (0.9, 0.1), (0.1, 0.9), (0.9, 0.9), (0.5, 0.5)]
        for (i, pt) in pts.enumerated() {
            if d.add(ScreenPoint(x: pt.0, y: pt.1), at: Double(i) * 0.05) != nil { any = true }
        }
        if d.flush() != nil { any = true }
        XCTAssertFalse(any)
    }
}

final class ElementMapTests: XCTestCase {
    func testHitTestTopmostWins() {
        let map = ElementMap(elements: [
            Element(id: "bg", rect: Rect(x: 0, y: 0, w: 1, h: 1)),
            Element(id: "cta", role: "button", label: "Sign up", rect: Rect(x: 0.4, y: 0.4, w: 0.2, h: 0.2)),
        ])
        XCTAssertEqual(map.hitTest(ScreenPoint(x: 0.5, y: 0.5))?.id, "cta")
        XCTAssertEqual(map.hitTest(ScreenPoint(x: 0.05, y: 0.05))?.id, "bg")
        XCTAssertNil(map.hitTest(ScreenPoint(x: 1.5, y: 1.5)))
    }

    // MARK: - resolve (element id, else region-id fallback) — Phase 5

    func testResolveInsideElementIsNamed() {
        let map = ElementMap(elements: [
            Element(id: "cta-primary", role: "button", label: "Sign up", rect: Rect(x: 0.4, y: 0.4, w: 0.2, h: 0.2)),
        ])
        let t = map.resolve(ScreenPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(t.id, "cta-primary")
        XCTAssertEqual(t.role, "button")
        XCTAssertEqual(t.label, "Sign up")
    }

    func testResolveOverlappingTopmostWins() {
        let map = ElementMap(elements: [
            Element(id: "panel", rect: Rect(x: 0, y: 0, w: 1, h: 1)),
            Element(id: "ok", rect: Rect(x: 0.4, y: 0.4, w: 0.2, h: 0.2)),   // last → topmost
        ])
        XCTAssertEqual(map.resolve(ScreenPoint(x: 0.5, y: 0.5)).id, "ok")
    }

    func testResolveMissFallsBackToRegion() {
        let map = ElementMap(elements: [
            Element(id: "cta", rect: Rect(x: 0.4, y: 0.4, w: 0.2, h: 0.2)),
        ])
        let t = map.resolve(ScreenPoint(x: 0.05, y: 0.95))   // outside cta → bottom-left cell
        XCTAssertEqual(t.id, "r2c0")
        XCTAssertEqual(t.role, "region")
        XCTAssertNil(t.label)
    }

    func testResolveEmptyMapIsAlwaysRegion() {
        let map = ElementMap()
        XCTAssertEqual(map.resolve(ScreenPoint(x: 0.5, y: 0.5)).id, "r1c1")
        XCTAssertEqual(map.resolve(ScreenPoint(x: 0.0, y: 0.0)).id, "r0c0")
        XCTAssertEqual(map.resolve(ScreenPoint(x: 0.9, y: 0.1)).id, "r0c2")
    }

    func testResolvePassesThroughMetadata() {
        let map = ElementMap(elements: [
            Element(id: "cta", role: "button", rect: Rect(x: 0.4, y: 0.4, w: 0.2, h: 0.2)),
        ])
        let t = map.resolve(ScreenPoint(x: 0.5, y: 0.5), dwellMs: 420, overlap: "during", confidence: 0.7)
        XCTAssertEqual(t.dwellMs, 420)
        XCTAssertEqual(t.overlap, "during")
        XCTAssertEqual(t.confidence, 0.7)
    }

    func testResolveHandlesNonFiniteCoordinate() {
        // A degenerate gaze point (e.g. a filter blow-up) must not trap the region fallback.
        XCTAssertEqual(ElementMap().resolve(ScreenPoint(x: .nan, y: .nan)).id, "r0c0")
        XCTAssertEqual(ElementMap().resolve(ScreenPoint(x: .infinity, y: 0.5)).id, "r1c0")
    }
}

final class EventsTests: XCTestCase {
    func testUtteranceRoundTrips() throws {
        let u = Utterance(
            tStart: 12.3,
            tEnd: 14.1,
            text: "make this bigger",
            speechConfidence: 0.91,
            gazeTargets: [
                GazeTarget(id: "cta-primary", role: "button", label: "Sign up",
                           dwellMs: 620, overlap: "during", confidence: 0.8),
            ],
            primaryTarget: "cta-primary",
            voiceActivity: VoiceActivity(jawOpenMean: 0.33, peak: 0.6)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(u)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"type\":\"utterance\""))
        XCTAssertTrue(json.contains("\"primaryTarget\":\"cta-primary\""))
        XCTAssertEqual(try JSONDecoder().decode(Utterance.self, from: data), u)
    }
}

private func variance(_ xs: [Double]) -> Double {
    let m = xs.reduce(0, +) / Double(xs.count)
    return xs.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count)
}
