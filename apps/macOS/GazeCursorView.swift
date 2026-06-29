import GazeKit
import SwiftUI

/// Phase 2 run screen: a translucent gaze cursor (a ring) at the smoothed, mapped position
/// within the view bounds, an RMS-error readout, and a Recalibrate button. The cursor
/// position is the model output already smoothed by the view model's 1€ filter.
struct GazeCursorView: View {
    @ObservedObject var calibration: CalibrationViewModel
    var onRecalibrate: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(white: 0.12)

                if calibration.cameraBlocked {
                    CameraIssueView(authorization: calibration.authorization,
                                    errorMessage: calibration.errorMessage)
                } else {
                    // Recent fixations — translucent discs sized by dwell time.
                    ForEach(calibration.fixationEvents.suffix(15), id: \.tStart) { event in
                        FixationMarker(dwell: event.tEnd - event.tStart)
                            .position(x: clamp(event.point.x) * geo.size.width,
                                      y: clamp(event.point.y) * geo.size.height)
                    }

                    if let point = calibration.cursor {
                        GazeRing()
                            .opacity(calibration.headDrifted ? 0.35 : 1)
                            .position(x: clamp(point.x) * geo.size.width,
                                      y: clamp(point.y) * geo.size.height)
                    } else {
                        Text("Move your eyes — the cursor follows your gaze.")
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    VStack {
                        HStack(alignment: .top) {
                            readout
                            Spacer()
                            Button("Recalibrate", action: onRecalibrate)
                                .controlSize(.large)
                        }
                        Spacer()
                        if calibration.headDrifted { driftWarning }
                        HStack(alignment: .bottom, spacing: 12) {
                            utteranceCard
                            Spacer(minLength: 12)
                            VStack(alignment: .trailing, spacing: 8) {
                                speechStatus
                                talkButton
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Gaze cursor")
                .font(.headline)
                .foregroundStyle(.white)
            if let rms = calibration.rmsErrorPx {
                Text(String(format: "RMS error: %.0f px", rms))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text("Fixations: \(calibration.fixationCount)")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            if let last = calibration.fixationEvents.last {
                Text(String(format: "last dwell: %.0f ms", (last.tEnd - last.tStart) * 1000))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var driftWarning: some View {
        Label("Head moved — recalibrate for accuracy", systemImage: "exclamationmark.triangle.fill")
            .font(.callout.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.9), in: Capsule())
            .padding(.bottom, 8)
    }

    /// Hold to capture speech; release to fuse it with the gaze held during the hold.
    private var talkButton: some View {
        let listening = calibration.isTalking
        return Label(listening ? "Listening…" : "Hold to Talk",
                     systemImage: listening ? "mic.fill" : "mic")
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(listening ? Color.accentColor : Color.white.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !calibration.isTalking { Task { await calibration.startTalking() } }
                    }
                    .onEnded { _ in
                        Task { await calibration.stopTalking() }
                    }
            )
    }

    @ViewBuilder
    private var speechStatus: some View {
        switch calibration.speechState {
        case .denied:
            Label("Mic/speech access denied", systemImage: "mic.slash")
                .font(.caption).foregroundStyle(.orange)
        case .noSpeech:
            Text("Didn’t catch that")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
        case .error(let message):
            Text(message)
                .font(.caption).foregroundStyle(.red)
                .frame(maxWidth: 240, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        case .listening, .idle:
            EmptyView()
        }
    }

    /// The most recent fused utterance: recognized text, the resolved (or ambiguous) target, the
    /// ranked alternatives, and the lips/speech signals.
    @ViewBuilder
    private var utteranceCard: some View {
        if let u = calibration.lastUtterance {
            VStack(alignment: .leading, spacing: 4) {
                Text("“\(u.text)”")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                targetLine(u)
                ForEach(Array(u.gazeTargets.prefix(3).enumerated()), id: \.offset) { _, t in
                    Text("\(t.id) · \(t.overlap ?? "?") · \(Int(t.dwellMs ?? 0)) ms")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text(String(format: "jaw peak %.2f · speech %.0f%%", u.voiceActivity.peak, u.speechConfidence * 100))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(12)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: 320, alignment: .leading)
        }
    }

    @ViewBuilder
    private func targetLine(_ u: Utterance) -> some View {
        if let primary = u.primaryTarget {
            Text("→ \(primary)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.green)
        } else if !u.gazeTargets.isEmpty {
            Text("→ ambiguous (\(u.gazeTargets.count) targets)")
                .font(.caption).foregroundStyle(.yellow)
        } else {
            Text("→ no gaze target")
                .font(.caption).foregroundStyle(.white.opacity(0.5))
        }
    }

    /// Keep the ring on-screen even if the quadratic mapping extrapolates outside [0, 1].
    private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
}

/// Translucent gaze cursor: a soft filled ring with a faint center dot.
private struct GazeRing: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.accentColor.opacity(0.15))
            Circle().stroke(Color.accentColor.opacity(0.9), lineWidth: 3)
            Circle().fill(Color.accentColor.opacity(0.8)).frame(width: 8, height: 8)
        }
        .frame(width: 44, height: 44)
        .shadow(color: .accentColor.opacity(0.5), radius: 8)
        .allowsHitTesting(false)
    }
}

/// A past fixation: a translucent orange disc whose size grows with dwell time.
private struct FixationMarker: View {
    let dwell: TimeInterval   // seconds

    var body: some View {
        let size = min(56, 18 + CGFloat(dwell) * 36)
        Circle()
            .fill(Color.orange.opacity(0.12))
            .overlay(Circle().stroke(Color.orange.opacity(0.6), lineWidth: 1.5))
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }
}
