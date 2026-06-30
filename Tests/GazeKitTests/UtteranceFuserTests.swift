import XCTest
@testable import GazeKit

final class UtteranceFuserTests: XCTestCase {
    private let fuser = UtteranceFuser()
    private let window = SpeechResult(text: "make this bigger", confidence: 0.9, tStart: 10.0, tEnd: 11.0)

    private func fix(_ start: TimeInterval, _ end: TimeInterval, at p: ScreenPoint = ScreenPoint(x: 0.5, y: 0.5)) -> Fixation {
        Fixation(start: start, end: end, centroid: p)
    }

    func testDuringOutranksLeadingWithComparableDwell() {
        let during = fix(10.2, 10.8, at: ScreenPoint(x: 0.5, y: 0.5))   // intersects window
        let leading = fix(9.2, 9.8, at: ScreenPoint(x: 0.1, y: 0.1))    // ends 0.2s before, within leadMargin
        let u = fuser.fuse(speech: window, fixations: [leading, during], mouthSamples: [])
        XCTAssertEqual(u.gazeTargets.first?.overlap, "during")
        XCTAssertEqual(u.gazeTargets.first?.id, "r1c1")
        XCTAssertEqual(u.gazeTargets.last?.overlap, "leading")
    }

    func testLongerDwellWinsWithinClass() {
        let longer = fix(10.0, 11.0, at: ScreenPoint(x: 0.2, y: 0.2))   // 1000ms
        let shorter = fix(10.4, 10.8, at: ScreenPoint(x: 0.8, y: 0.8))  // 400ms
        let u = fuser.fuse(speech: window, fixations: [shorter, longer], mouthSamples: [])
        XCTAssertEqual(u.gazeTargets.map(\.id), ["r0c0", "r2c2"])
    }

    func testFarFixationExcluded() {
        let far = fix(8.0, 9.0)   // ends 1.0s before window — beyond leadMargin
        let u = fuser.fuse(speech: window, fixations: [far], mouthSamples: [])
        XCTAssertTrue(u.gazeTargets.isEmpty)
        XCTAssertNil(u.primaryTarget)
    }

    func testClearWinnerSetsPrimaryTarget() {
        let strong = fix(10.0, 11.0, at: ScreenPoint(x: 0.5, y: 0.5))   // during, 1000ms → 1.5
        let weak = fix(11.2, 11.5, at: ScreenPoint(x: 0.1, y: 0.9))     // trailing 0.2s, 300ms → 0.55
        let u = fuser.fuse(speech: window, fixations: [strong, weak], mouthSamples: [])
        XCTAssertEqual(u.primaryTarget, "r1c1")
    }

    func testNearTieLeavesPrimaryNil() {
        let a = fix(10.0, 10.5, at: ScreenPoint(x: 0.2, y: 0.2))   // during, 500ms → 1.25
        let b = fix(10.4, 10.92, at: ScreenPoint(x: 0.8, y: 0.8))  // during, 520ms → 1.26
        let u = fuser.fuse(speech: window, fixations: [a, b], mouthSamples: [])
        XCTAssertNil(u.primaryTarget)
        XCTAssertEqual(u.gazeTargets.count, 2)
    }

    func testSingleCandidateIsPrimary() {
        let only = fix(10.2, 10.8, at: ScreenPoint(x: 0.9, y: 0.1))
        let u = fuser.fuse(speech: window, fixations: [only], mouthSamples: [])
        XCTAssertEqual(u.primaryTarget, "r0c2")
    }

    func testNoFixationsStillEmitsText() {
        let u = fuser.fuse(speech: window, fixations: [], mouthSamples: [])
        XCTAssertEqual(u.type, .utterance)
        XCTAssertEqual(u.text, "make this bigger")
        XCTAssertTrue(u.gazeTargets.isEmpty)
        XCTAssertNil(u.primaryTarget)
        XCTAssertEqual(u.tStart, 10.0, accuracy: 1e-9)
        XCTAssertEqual(u.tEnd, 11.0, accuracy: 1e-9)
    }

    func testVoiceActivityComputedOverWindow() {
        let samples = [MouthSample(t: 10.2, openness: 0.3), MouthSample(t: 10.7, openness: 0.5)]
        let u = fuser.fuse(speech: window, fixations: [], mouthSamples: samples)
        XCTAssertEqual(u.voiceActivity.jawOpenMean, 0.4, accuracy: 1e-9)
        XCTAssertEqual(u.voiceActivity.peak, 0.5, accuracy: 1e-9)
    }

    func testConfidenceIsShareOfScore() throws {
        let u = fuser.fuse(speech: window, fixations: [fix(10.2, 10.8)], mouthSamples: [])
        let confidence = try XCTUnwrap(u.gazeTargets.first?.confidence)
        XCTAssertEqual(confidence, 1.0, accuracy: 1e-9)  // sole target → full share
    }

    func testRepeatedRegionAggregatesIntoOneTarget() {
        // Two during-fixations in the SAME 3×3 cell must collapse to one target with summed dwell,
        // not two competing duplicates that split the score and falsely tie the primary margin.
        let a = fix(10.1, 10.4, at: ScreenPoint(x: 0.50, y: 0.50))   // 300ms → r1c1
        let b = fix(10.5, 10.9, at: ScreenPoint(x: 0.55, y: 0.52))   // 400ms → r1c1
        let u = fuser.fuse(speech: window, fixations: [a, b], mouthSamples: [])
        XCTAssertEqual(u.gazeTargets.count, 1)
        XCTAssertEqual(u.gazeTargets.first?.id, "r1c1")
        XCTAssertEqual(u.gazeTargets.first?.dwellMs ?? 0, 700, accuracy: 1e-9)
        XCTAssertEqual(u.primaryTarget, "r1c1")   // sole region → unambiguous
    }

    // MARK: - Element resolution (Phase 5)

    private let cta = Element(
        id: "cta-primary", role: "button", label: "Sign up",
        rect: Rect(x: 0.4, y: 0.4, w: 0.2, h: 0.2)
    )

    func testOverlappingFixationResolvesToNamedElement() {
        let map = ElementMap(elements: [cta])
        let during = fix(10.2, 10.8, at: ScreenPoint(x: 0.5, y: 0.5))   // inside cta, intersects window
        let u = fuser.fuse(speech: window, fixations: [during], mouthSamples: [], elements: map)
        XCTAssertEqual(u.gazeTargets.first?.id, "cta-primary")
        XCTAssertEqual(u.gazeTargets.first?.role, "button")
        XCTAssertEqual(u.gazeTargets.first?.label, "Sign up")
        XCTAssertEqual(u.primaryTarget, "cta-primary")
    }

    func testRepeatedElementAggregatesIntoOneTarget() {
        let map = ElementMap(elements: [cta])
        let a = fix(10.1, 10.4, at: ScreenPoint(x: 0.45, y: 0.45))   // 300ms, inside cta
        let b = fix(10.5, 10.9, at: ScreenPoint(x: 0.55, y: 0.55))   // 400ms, inside cta
        let u = fuser.fuse(speech: window, fixations: [a, b], mouthSamples: [], elements: map)
        XCTAssertEqual(u.gazeTargets.count, 1)
        XCTAssertEqual(u.gazeTargets.first?.id, "cta-primary")
        XCTAssertEqual(u.gazeTargets.first?.dwellMs ?? 0, 700, accuracy: 1e-9)
    }

    func testEmptyMapReproducesRegionOutput() {
        // The defaulted empty map and an explicit empty map must both yield region ids (Phase 4 behavior).
        let during = fix(10.2, 10.8, at: ScreenPoint(x: 0.5, y: 0.5))
        let implicit = fuser.fuse(speech: window, fixations: [during], mouthSamples: [])
        let explicit = fuser.fuse(speech: window, fixations: [during], mouthSamples: [], elements: ElementMap())
        XCTAssertEqual(implicit.gazeTargets.first?.id, "r1c1")
        XCTAssertEqual(implicit.gazeTargets.first?.role, "region")
        XCTAssertEqual(explicit.gazeTargets, implicit.gazeTargets)
    }

    func testInvertedSpeechWindowDoesNotTrap() {
        // A malformed window (tStart > tEnd) must not trap when building the voice-activity range.
        let inverted = SpeechResult(text: "x", confidence: 0.5, tStart: 11.0, tEnd: 10.0)
        let u = fuser.fuse(speech: inverted, fixations: [], mouthSamples: [])
        XCTAssertEqual(u.text, "x")
        XCTAssertEqual(u.voiceActivity.jawOpenMean, 0, accuracy: 1e-9)
    }

    func testRegionIDGrid() {
        XCTAssertEqual(UtteranceFuser.regionID(for: ScreenPoint(x: 0.0, y: 0.0)), "r0c0")
        XCTAssertEqual(UtteranceFuser.regionID(for: ScreenPoint(x: 0.5, y: 0.5)), "r1c1")
        XCTAssertEqual(UtteranceFuser.regionID(for: ScreenPoint(x: 0.9, y: 0.1)), "r0c2")
        XCTAssertEqual(UtteranceFuser.regionID(for: ScreenPoint(x: 1.0, y: 1.0)), "r2c2")  // clamps
    }
}
