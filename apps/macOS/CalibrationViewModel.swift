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
    /// True when the head has drifted past `driftThreshold` from the calibration pose, so
    /// the mapping is likely stale — the UI dims the cursor and prompts a recalibrate.
    @Published private(set) var headDrifted = false
    private let fixationDetector = FixationDetector()
    private let maxLoggedFixations = 60

    // MARK: Utterance stream (Phase 4) — speech fused with the gaze held while speaking.
    enum SpeechState: Equatable { case idle, listening, noSpeech, denied, error(String) }
    @Published var speechState: SpeechState = .idle
    @Published private(set) var isTalking = false
    @Published private(set) var lastUtterance: Utterance?
    @Published private(set) var utteranceCount = 0

    private let fuser = UtteranceFuser()
    private let speech = SpeechRecognizer()
    private var speechAuthorized = false
    private var recentFixations: [Fixation] = []
    private var recentMouthSamples: [MouthSample] = []
    private let maxRecentFixations = 30
    private let maxRecentMouthSamples = 600        // ~20s at 30fps
    private var lastSampleTime: TimeInterval = 0   // newest sample.t — the gaze clock for windows
    private var talkStartTime: TimeInterval = 0

    // Head-pose drift: a baseline captured during calibration vs. the live pose at run time.
    private var calibrationHeadPose: HeadPose?
    private var calibrationSpan: Double?
    private var captureHeadPoses: [HeadPose] = []
    private var captureSpans: [Double] = []
    private let driftThreshold = 0.12        // pose drift, radians (~7°); tunable
    private let spanRatioThreshold = 0.10    // distance drift: ±10% of inter-eye span; tunable

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
        headDrifted = false
        recentFixations = []
        recentMouthSamples = []
        lastUtterance = nil
        utteranceCount = 0
        isTalking = false
        speechState = .idle
        lastSampleTime = 0
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
        if isTalking { isTalking = false; _ = await speech.stopCapture() }
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
        captureHeadPoses = []
        captureSpans = []
        calibrationHeadPose = nil
        calibrationSpan = nil
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
            calibrationHeadPose = meanPose(captureHeadPoses)
            calibrationSpan = captureSpans.isEmpty ? nil : captureSpans.reduce(0, +) / Double(captureSpans.count)
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
            if isCapturing {
                session.add(targetIndex: currentDotIndex, gx: gx, gy: gy)
                captureHeadPoses.append(sample.headPose)
                captureSpans.append(sample.headSpan)
            }
        case .running:
            guard let model = calibrationModel else { return }
            lastSampleTime = sample.t
            appendMouthSample(MouthSample(sample))
            let mapped = filter.filter(model.map(gx, gy), at: sample.t)
            cursor = mapped
            if let basePose = calibrationHeadPose {
                let rotated = sample.headPose.angularDistance(to: basePose) > driftThreshold
                let leaned = calibrationSpan.map { $0 > 1e-6 && abs(sample.headSpan / $0 - 1) > spanRatioThreshold } ?? false
                headDrifted = rotated || leaned
            }
            if let fixation = fixationDetector.add(mapped, at: sample.t) {
                record(fixation, confidence: headDrifted ? 0.5 : 1)
            }
        case .idle:
            break
        }
    }

    /// Append a completed fixation as a Claude-facing event, capping the in-memory log.
    private func record(_ fixation: Fixation, confidence: Double = 1) {
        fixationCount += 1
        fixationEvents.append(FixationEvent(fixation, confidence: confidence))
        if fixationEvents.count > maxLoggedFixations {
            fixationEvents.removeFirst(fixationEvents.count - maxLoggedFixations)
        }
        recentFixations.append(fixation)
        if recentFixations.count > maxRecentFixations {
            recentFixations.removeFirst(recentFixations.count - maxRecentFixations)
        }
    }

    private func appendMouthSample(_ s: MouthSample) {
        recentMouthSamples.append(s)
        if recentMouthSamples.count > maxRecentMouthSamples {
            recentMouthSamples.removeFirst(recentMouthSamples.count - maxRecentMouthSamples)
        }
    }

    /// Per-axis mean of a set of head poses. Returns a zero pose for empty input.
    private func meanPose(_ poses: [HeadPose]) -> HeadPose {
        guard !poses.isEmpty else { return HeadPose() }
        let n = Double(poses.count)
        return HeadPose(
            yaw: poses.reduce(0) { $0 + $1.yaw } / n,
            pitch: poses.reduce(0) { $0 + $1.pitch } / n,
            roll: poses.reduce(0) { $0 + $1.roll } / n
        )
    }

    // MARK: Push-to-talk (Phase 4)

    /// Begin capturing speech. Requests microphone + speech authorization on first use.
    func startTalking() async {
        guard activity == .running, !isTalking else { return }
        if !speechAuthorized {
            speechAuthorized = await speech.requestAuthorization()
            guard speechAuthorized else { speechState = .denied; return }
        }
        do {
            try speech.startCapture()
            talkStartTime = lastSampleTime
            isTalking = true
            speechState = .listening
        } catch {
            let message = (error as? SpeechRecognizer.CaptureError)?.errorDescription ?? error.localizedDescription
            speechState = .error(message)
        }
    }

    /// Stop capturing, fuse the recognized text with the gaze held while speaking, and publish the
    /// resulting `Utterance`. The window is `[talkStart, release]` on the shared gaze clock.
    func stopTalking() async {
        guard isTalking else { return }
        isTalking = false
        let windowEnd = lastSampleTime
        // The user may have held their gaze on the target through the whole utterance, so that
        // fixation hasn't been emitted yet — flush it so fusion can see it.
        if let inProgress = fixationDetector.flush() {
            record(inProgress, confidence: headDrifted ? 0.5 : 1)
        }
        // Snapshot before the await so reentrant sample handling can't change what we fuse.
        let fixations = recentFixations
        let mouthSamples = recentMouthSamples
        let windowStart = talkStartTime

        guard let transcription = await speech.stopCapture() else {
            speechState = .noSpeech
            return
        }
        let result = SpeechResult(
            text: transcription.text,
            confidence: transcription.confidence,
            tStart: windowStart,
            tEnd: max(windowStart, windowEnd)
        )
        lastUtterance = fuser.fuse(speech: result, fixations: fixations, mouthSamples: mouthSamples)
        utteranceCount += 1
        speechState = .idle
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
