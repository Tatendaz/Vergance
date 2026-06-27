import AVFoundation
import CoreVideo
import GazeKit

/// `GazeSensor` for macOS: wires `CameraSession` → `VisionFaceDetector` →
/// `GazeFeatures.sample(...)` and yields `GazeSample`s into an `AsyncStream`.
///
/// In addition to the protocol's sample stream, it exposes the latest detected
/// `FaceLandmarks` (per processed frame, face or not) via `onFrame` so the UI
/// can draw an overlay, plus the underlying `AVCaptureSession` and the mirroring
/// flag for the preview layer.
final class WebcamSensor: GazeSensor {

    let samples: AsyncStream<GazeSample>

    /// Called on a background queue for every processed frame with the detected
    /// landmarks (`nil` when no face) and the frame's pixel dimensions.
    var onFrame: (@Sendable (FaceLandmarks?, CGSize) -> Void)?

    /// The capture session, for attaching a preview layer.
    var session: AVCaptureSession { camera.session }

    /// Whether the active device should be mirrored for display (front camera).
    var isMirrored: Bool { camera.isMirrored }

    private let camera = CameraSession()
    private let detector = VisionFaceDetector()
    private let continuation: AsyncStream<GazeSample>.Continuation

    init() {
        var capturedContinuation: AsyncStream<GazeSample>.Continuation!
        samples = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { capturedContinuation = $0 }
        continuation = capturedContinuation
        camera.onFrame = { [weak self] pixelBuffer, time in
            self?.handle(pixelBuffer, time: time)
        }
    }

    func start() async throws {
        try await camera.start()
    }

    func stop() {
        camera.stop()
        continuation.finish()
    }

    /// Awaitable stop: suspends until the camera has fully stopped, then ends the stream.
    /// Used on mode switches so a new sensor doesn't race the device.
    func stopAndWait() async {
        await camera.stopAndWait()
        continuation.finish()
    }

    private func handle(_ pixelBuffer: CVPixelBuffer, time: CMTime) {
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        let landmarks = detector.detect(in: pixelBuffer)
        onFrame?(landmarks, size)
        guard let landmarks else { return }
        let sample = GazeFeatures.sample(landmarks, t: time.seconds, confidence: 1)
        continuation.yield(sample)
    }
}
