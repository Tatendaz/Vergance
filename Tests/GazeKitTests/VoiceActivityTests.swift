import XCTest
@testable import GazeKit

final class VoiceActivityTests: XCTestCase {
    func testReductionComputesMeanAndPeakOverWindow() {
        let samples = [
            MouthSample(t: 9.0, openness: 0.9),   // before window — ignored
            MouthSample(t: 10.1, openness: 0.2),
            MouthSample(t: 10.5, openness: 0.6),
            MouthSample(t: 10.9, openness: 0.4),
            MouthSample(t: 11.5, openness: 0.8),  // after window — ignored
        ]
        let va = VoiceActivity(from: samples, in: 10.0 ... 11.0)
        XCTAssertEqual(va.jawOpenMean, 0.4, accuracy: 1e-9)   // (0.2 + 0.6 + 0.4) / 3
        XCTAssertEqual(va.peak, 0.6, accuracy: 1e-9)
    }

    func testEmptyWindowReducesToZeros() {
        XCTAssertEqual(VoiceActivity(from: [], in: 0 ... 1), VoiceActivity(jawOpenMean: 0, peak: 0))
        // samples exist but none fall in the window
        let outside = [MouthSample(t: 5, openness: 0.5)]
        XCTAssertEqual(VoiceActivity(from: outside, in: 0 ... 1), VoiceActivity(jawOpenMean: 0, peak: 0))
    }

    func testMouthSampleLiftsOffGazeSample() {
        let s = GazeSample(t: 2.0, gazeFeatures: [0, 0], mouth: MouthSignal(openness: 0.3))
        XCTAssertEqual(MouthSample(s), MouthSample(t: 2.0, openness: 0.3))
    }
}
