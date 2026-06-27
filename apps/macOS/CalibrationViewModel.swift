import AVFoundation
import GazeKit
import SwiftUI

/// Drives Phase 2. Owns a `WebcamSensor` (camera authorization handled exactly like
/// `ProbeViewModel`) and orchestrates two activities over the live gaze stream:
///
/// - **Calibrate** — iterate the 9 targets; per dot, settle briefly then capture ~30
///   frames of the live gaze feature into a `CalibrationSession`, then `fit()` a model.
/// - **Run** — map each live gaze feature through the learned model, smooth it with a
///   1€ filter, and publish the resulting normalized screen point as the cursor.
///
/// The learned `calibrationModel`/`rmsErrorPx` persist across camera stop/start and are
/// only replaced when a new fit succeeds, so a failed recalibration never loses the
/// working model.
@MainActor
final class CalibrationViewModel: ObservableObject {

    // MARK: Capture / permission state (mirrors ProbeViewModel).
    @Published var authorization: AVAuthorizationStatus = CameraSession.authorizationStatus
    @Published var isRunning = false
    @Published var errorMessage: String?

    // MARK: Calibration progress.
    enum CalibrationState: Equatable { case idle, running, done, failed }
    @Published var calibrationState: CalibrationState = .idle
    @Published var currentDotIndex = 0
    /// True only inside a dot's capture window (vs. the settle pause) — drives the dot animation.
    @Published var isCapturing = false

    // MARK: Results.
    @Published var calibrationModel: CalibrationModel?
    @Published var rmsErrorPx: Double?

    // MARK: Run output — smoothed, normalized [0, 1], origin top-left.
    @Published var cursor: ScreenPoint?

    // MARK: Event stream (Phase 3) — fixations detected from the live calibrated gaze.
    @Published var sessionStart: SessionStart?
    @Published private(set) var fixationEvents: [FixationEvent] = []
    /// Total fixations this Run — never trimmed, unlike the capped `fixationEvents` history.
    @Published private(set) var fixationCount = 0
    private let fixationDetector = FixationDetector()
    private let maxLoggedFixations = 60

    /// Pixel size of the calibration view, reported by `CalibrationView`. Used as the
    /// screenWidth/Height for `fit()` (only scales the reported RMS error in pixels).
    var calibrationPixelSize = CGSize(width: 800, height: 600)

    let targets = CalibrationTargets.ninePoint

    /// The dot to display right now, if a calibration run is active.
    var currentTarget: ScreenPoint? {
        guard calibrationState == .running, targets.indices.contains(currentDotIndex) else { return nil }
        return targets[currentDotIndex]
    }

    /// Whether a calibration sequence is actively collecting — used to lock the mode picker.
    var isCalibrating: Bool { calibrationState == .running }

    /// The camera can't run (permission denied/restricted, or a start error). The
    /// Calibrate/Run screens show a message instead of dead-ending.
    var cameraBlocked: Bool {
        authorization == .denied || authorization == .restricted || errorMessage != nil
    }

    // Per-dot capture timing.
    private let framesPerDot = 30                 // ~1s at 30fps
    private let settleDuration: Duration = .milliseconds(500)
    private let captureTimeout: TimeInterval = 3  // safety break if the face is lost

    // 1€ smoothing for the run cursor. Operating on the normalized [0,1] screen signal at
    // ~30fps: minCutoff 1.0Hz gives firm jitter rejection while still (new-sample weight
    // ~0.17), and beta 0.5 lets the cutoff climb on deliberate saccades so the cursor keeps
    // up without lag. dCutoff left at the standard 1.0Hz. Tune live (see report).
    private let filter = OneEuroFilter2D(minCutoff: 1.0, beta: 0.5, dCutoff: 1.0)

    private enum Activity { case idle, calibrating, running }
    private var activity: Activity = .idle

    private var session = CalibrationSession()
    private var sensor: WebcamSensor?
    private var samplesTask: Task<Void, Never>?
    private var calibrationTask: Task<Void, Never>?
    private var isStarting = false
    private var stopRequested = false

    // MARK: Mode entry (called by ContentView on a mode switch)

    /// Enter Calibrate mode: bring the camera up and wait (idle) for the user to tap Start.
    /// Does not begin the dot sequence.
    func enterCalibrateMode() async {
        activity = .idle
        cursor = nil
        await startCamera()
    }

    /// Enter Run mode: bring the camera up, reset the smoother, and begin cursoring.
    func enterRunMode() async {
        await startCamera()
        guard isRunning else { return }   // camera denied/failed — don't enter Run with no sensor
        // A completed calibration is required to map gaze; don't publish a session_start
        // with a fake 0px error when uncalibrated. (The UI also gates Run on this.)
        guard calibrationModel != nil, let rms = rmsErrorPx else { return }
        filter.reset()
        fixationDetector.reset()
        fixationEvents = []
        fixationCount = 0
        cursor = nil
        sessionStart = SessionStart(
            screenW: Int(calibrationPixelSize.width),
            screenH: Int(calibrationPixelSize.height),
            calibrationPoints: targets.count,
            rmsErrorPx: rms
        )
        activity = .running
    }

    /// Full stop when leaving Phase 2 (e.g. back to Probe). Keeps the learned model.
    func stop() async {
        cancelCalibration()
        if let fixation = fixationDetector.flush() { record(fixation) }
        activity = .idle
        cursor = nil
        await stopCamera()
    }

    // MARK: Calibration control

    /// Begin the 9-dot sequence (requires the camera to be running).
    func startCalibration() {
        guard isRunning else { return }
        cancelCalibration()
        session = CalibrationSession(targets: targets)
        currentDotIndex = 0
        calibrationState = .running
        activity = .calibrating
        calibrationTask = Task { [weak self] in await self?.runCalibrationSequence() }
    }

    func cancelCalibration() {
        calibrationTask?.cancel()
        calibrationTask = nil
        isCapturing = false
        if calibrationState == .running { calibrationState = .idle }
        if activity == .calibrating { activity = .idle }
    }

    /// Walk the targets: per dot, show + settle (no capture), then capture until ~30 frames
    /// are recorded or a safety timeout elapses. After the last dot, fit the model.
    private func runCalibrationSequence() async {
        for i in targets.indices {
            if Task.isCancelled { return }
            currentDotIndex = i

            // Settle: the eyes are still saccading onto the new dot — capture nothing.
            isCapturing = false
            try? await Task.sleep(for: settleDuration)
            if Task.isCancelled { return }

            // Capture window: `handle(_:)` records each incoming sample while isCapturing.
            isCapturing = true
            let start = Date()
            while session.sampleCount(targetIndex: i) < framesPerDot {
                if Task.isCancelled { return }
                if Date().timeIntervalSince(start) > captureTimeout { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            isCapturing = false
        }
        if Task.isCancelled { return }

        // Fit from the per-target medians; pixel size only scales the reported error.
        activity = .idle
        calibrationTask = nil
        let w = max(1, Int(calibrationPixelSize.width))
        let h = max(1, Int(calibrationPixelSize.height))
        if let result = session.fit(screenWidth: w, screenHeight: h) {
            calibrationModel = result.model
            rmsErrorPx = result.rmsErrorPx
            calibrationState = .done
        } else {
            calibrationState = .failed
        }
    }

    // MARK: Sample handling

    private func handle(_ sample: GazeSample) {
        guard sample.gazeFeatures.count >= 2 else { return }
        let gx = sample.gazeFeatures[0]
        let gy = sample.gazeFeatures[1]
        switch activity {
        case .calibrating:
            // Record only inside a capture window. The gaze feature stays in true-image space
            // (no Phase-1 display mirror) so the model learns one consistent convention.
            if isCapturing { session.add(targetIndex: currentDotIndex, gx: gx, gy: gy) }
        case .running:
            guard let model = calibrationModel else { return }
            let mapped = filter.filter(model.map(gx, gy), at: sample.t)
            cursor = mapped
            if let fixation = fixationDetector.add(mapped, at: sample.t) {
                record(fixation)
            }
        case .idle:
            break
        }
    }

    /// Append a completed fixation as a Claude-facing event, capping the in-memory log.
    private func record(_ fixation: Fixation) {
        fixationCount += 1
        fixationEvents.append(FixationEvent(fixation))
        if fixationEvents.count > maxLoggedFixations {
            fixationEvents.removeFirst(fixationEvents.count - maxLoggedFixations)
        }
    }

    // MARK: Camera lifecycle (mirrors ProbeViewModel, incl. the stop-during-start guard)

    private func startCamera() async {
        guard !isRunning, !isStarting else { return }
        isStarting = true
        stopRequested = false
        defer { isStarting = false }
        errorMessage = nil

        var status = CameraSession.authorizationStatus
        if status == .notDetermined {
            _ = await CameraSession.requestAccess()
            if stopRequested { return }
            status = CameraSession.authorizationStatus
        }
        authorization = status
        guard status == .authorized else { return }

        let sensor = WebcamSensor()
        self.sensor = sensor
        samplesTask = Task { [weak self] in
            for await sample in sensor.samples { self?.handle(sample) }
        }

        do {
            try await sensor.start()
            guard !stopRequested, self.sensor === sensor else {
                sensor.stop()
                return
            }
            isRunning = true
        } catch {
            errorMessage = error.localizedDescription
            teardownCamera()
        }
    }

    private func stopCamera() async {
        stopRequested = true
        await sensor?.stopAndWait()
        teardownCamera()
    }

    private func teardownCamera() {
        samplesTask?.cancel()
        samplesTask = nil
        sensor = nil
        isRunning = false
    }
}
