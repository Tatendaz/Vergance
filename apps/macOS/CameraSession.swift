import AVFoundation
import CoreVideo

/// Thin wrapper around `AVCaptureSession` + `AVCaptureVideoDataOutput`.
///
/// Picks the default video device (the built-in webcam on most Macs), vends
/// `CVPixelBuffer` frames to `onFrame` on a background queue, and exposes the
/// session so a preview layer can attach. The frames handed to Vision are kept
/// un-mirrored; mirroring for a front camera is applied only at display time.
/// Marked `@unchecked Sendable`: all mutable state is confined to `sessionQueue`
/// (configuration) or set once before `start()` (`onFrame`), and `AVCaptureSession`
/// is internally thread-safe — so it is safe to hand `self` to the capture queue.
final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// Errors surfaced while configuring the capture graph.
    enum CameraError: LocalizedError {
        case noDevice
        case cannotAddInput
        case cannotAddOutput

        var errorDescription: String? {
            switch self {
            case .noDevice: return "No video capture device was found."
            case .cannotAddInput: return "Could not add the camera input to the capture session."
            case .cannotAddOutput: return "Could not add the video output to the capture session."
            }
        }
    }

    /// The capture session a preview layer attaches to.
    let session = AVCaptureSession()

    /// `true` when the preview should be mirrored (selfie view). The built-in Mac
    /// webcam is front-facing but frequently reports `.unspecified`, so we mirror
    /// anything that isn't an explicit rear camera.
    private(set) var isMirrored = false

    /// Called for every delivered frame on `videoQueue` (a background queue).
    /// The `CVPixelBuffer` is un-mirrored, oriented as the device delivers it.
    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.firesoftware.vergance.camera.session")
    private let videoQueue = DispatchQueue(label: "com.firesoftware.vergance.camera.video")
    private var isConfigured = false

    // MARK: Authorization

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: Lifecycle

    /// Configures the graph if needed and starts running, off the main thread.
    /// Throws if no device is available or the graph can't be built.
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try self.configureIfNeeded()
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // MARK: Configuration

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraError.noDevice
        }
        // Mirror for the built-in / front webcam (the common case) so the preview reads
        // like a mirror; only an explicit rear camera stays un-mirrored. Mac built-ins
        // frequently report `.unspecified`, so treat anything that isn't `.back` as front.
        isMirrored = (device.position != .back)

        session.beginConfiguration()
        session.sessionPreset = .high

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            throw CameraError.cannotAddOutput
        }
        session.addOutput(videoOutput)

        // Keep frames delivered to Vision un-mirrored and deterministic; the
        // preview layer handles mirroring for display on its own connection.
        if let connection = videoOutput.connection(with: .video) {
            connection.automaticallyAdjustsVideoMirroring = false
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
        }

        session.commitConfiguration()
        isConfigured = true
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        onFrame?(pixelBuffer, time)
    }
}
