import AVFoundation
import GazeKit
import Speech

/// Push-to-talk speech capture: `SFSpeechRecognizer` + `AVAudioEngine`, on-device only.
///
/// Produces one final transcription per hold. The caller stamps the capture window from the
/// shared gaze clock and fuses it with the fixation stream (see ``CalibrationViewModel`` and
/// `UtteranceFuser`) — keeping `Speech.framework` out of the platform-agnostic core.
final class SpeechRecognizer {

    /// What the recognizer heard — the words and a confidence. The capture window is added by the
    /// caller, which owns the gaze clock.
    struct Transcription {
        let text: String
        let confidence: Double
    }

    enum CaptureError: LocalizedError {
        case recognizerUnavailable
        case onDeviceUnavailable
        case audioEngine(Error)

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable: return "The speech recognizer is unavailable right now."
            case .onDeviceUnavailable: return "On-device speech recognition isn't available for this language."
            case .audioEngine(let e): return "Audio engine error: \(e.localizedDescription)"
            }
        }
    }

    private let recognizer = SFSpeechRecognizer()   // current locale
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Request microphone + speech-recognition authorization. Returns true only if both granted.
    func requestAuthorization() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { return false }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    /// Begin capturing audio into a fresh recognition request. On-device recognition is required;
    /// throws rather than falling back to a network request (raw audio never leaves the device).
    func startCapture() throws {
        guard let recognizer, recognizer.isAvailable else { throw CaptureError.recognizerUnavailable }
        guard recognizer.supportsOnDeviceRecognition else { throw CaptureError.onDeviceUnavailable }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cleanup()
            throw CaptureError.audioEngine(error)
        }
    }

    /// Stop capturing and return the final transcription, or nil if nothing intelligible was heard.
    /// A silent hold (the common "no speech" case) resolves to nil rather than an error.
    func stopCapture() async -> Transcription? {
        guard let request, let recognizer else {
            cleanup()
            return nil
        }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request.endAudio()

        let resumed = ResumeGuard()
        let transcription: Transcription? = await withCheckedContinuation { cont in
            self.task = recognizer.recognitionTask(with: request) { result, error in
                // The framework calls this serially; the guard makes a double-callback safe.
                if error != nil {
                    resumed.once { cont.resume(returning: nil) }
                    return
                }
                guard let result, result.isFinal else { return }
                let best = result.bestTranscription
                let text = best.formattedString
                let value: Transcription? = text.isEmpty ? nil : Transcription(text: text, confidence: Self.meanConfidence(best))
                resumed.once { cont.resume(returning: value) }
            }
        }
        cleanup()
        return transcription
    }

    private func cleanup() {
        task?.cancel()
        task = nil
        request = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    /// Mean of the per-segment confidences across all segments. A segment the recognizer is unsure
    /// of reports 0, which should drag the mean down — so it's included, not filtered out.
    private static func meanConfidence(_ t: SFTranscription) -> Double {
        guard !t.segments.isEmpty else { return 0 }
        return t.segments.reduce(0.0) { $0 + Double($1.confidence) } / Double(t.segments.count)
    }
}

/// One-shot latch so a continuation is resumed at most once.
private final class ResumeGuard {
    private var done = false
    func once(_ body: () -> Void) {
        guard !done else { return }
        done = true
        body()
    }
}
