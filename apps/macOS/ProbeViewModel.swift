import AVFoundation
import GazeKit
import QuartzCore
import SwiftUI

/// Drives the webcam probe: owns the `WebcamSensor`, republishes its output as
/// `@Published` state for SwiftUI, and tracks camera authorization + FPS.
@MainActor
final class ProbeViewModel: ObservableObject {

    // Capture / permission state.
    @Published var authorization: AVAuthorizationStatus = CameraSession.authorizationStatus
    @Published var isRunning = false
    @Published var errorMessage: String?
    @Published var mirrored = false
    @Published var frameSize = CGSize(width: 16, height: 9)

    // Per-frame readout.
    @Published var latestLandmarks: FaceLandmarks?
    @Published var headPose = HeadPose()
    @Published var gaze = CGPoint.zero          // (gx, gy) raw pupil-offset feature
    @Published var mar: Double = 0              // mouth-aspect-ratio
    @Published var fps: Double = 0

    /// The capture session for the preview layer, available once started.
    var session: AVCaptureSession? { sensor?.session }

    /// Whether a face was detected in the most recent frame.
    var faceDetected: Bool { latestLandmarks != nil }

    private var sensor: WebcamSensor?
    private var samplesTask: Task<Void, Never>?
    private var lastFrameTime: CFTimeInterval?
    private var isStarting = false
    private var stopRequested = false

    // MARK: Control

    func start() async {
        // Re-entry guard: ignore overlapping Start taps while a start is in flight or running.
        guard !isRunning, !isStarting else { return }
        isStarting = true
        stopRequested = false
        defer { isStarting = false }
        errorMessage = nil

        var status = CameraSession.authorizationStatus
        if status == .notDetermined {
            _ = await CameraSession.requestAccess()
            if stopRequested { return }   // Stop tapped during the permission prompt.
            status = CameraSession.authorizationStatus
        }
        authorization = status
        guard status == .authorized else { return }

        let sensor = WebcamSensor()
        sensor.onFrame = { [weak self] landmarks, size in
            // Delivered on a background queue — hop to the main actor to publish.
            Task { @MainActor in self?.ingest(landmarks: landmarks, size: size) }
        }
        self.sensor = sensor

        samplesTask = Task { [weak self] in
            for await sample in sensor.samples {
                self?.apply(sample)
            }
        }

        do {
            try await sensor.start()
            // A Stop during the await above tears down and clears self.sensor; honor
            // that intent instead of flipping a torn-down session back to running.
            guard !stopRequested, self.sensor === sensor else {
                sensor.stop()
                return
            }
            mirrored = sensor.isMirrored
            isRunning = true
        } catch {
            errorMessage = error.localizedDescription
            teardown()
        }
    }

    func stop() async {
        stopRequested = true
        await sensor?.stopAndWait()
        teardown()
        latestLandmarks = nil
        fps = 0
        lastFrameTime = nil
    }

    private func teardown() {
        samplesTask?.cancel()
        samplesTask = nil
        sensor = nil
        isRunning = false
    }

    // MARK: Ingest

    private func ingest(landmarks: FaceLandmarks?, size: CGSize) {
        latestLandmarks = landmarks
        if size.width > 0, size.height > 0 { frameSize = size }
        updateFPS()
    }

    private func apply(_ sample: GazeSample) {
        headPose = sample.headPose
        if sample.gazeFeatures.count >= 2 {
            gaze = CGPoint(x: sample.gazeFeatures[0], y: sample.gazeFeatures[1])
        }
        mar = sample.mouth.openness
    }

    private func updateFPS() {
        let now = CACurrentMediaTime()
        defer { lastFrameTime = now }
        guard let last = lastFrameTime else { return }
        let dt = now - last
        guard dt > 0 else { return }
        let instantaneous = 1.0 / dt
        fps = fps == 0 ? instantaneous : fps * 0.9 + instantaneous * 0.1
    }
}
