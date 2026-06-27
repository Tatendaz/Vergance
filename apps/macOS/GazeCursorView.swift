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
                        if calibration.headDrifted {
                            Label("Head moved — recalibrate for accuracy", systemImage: "exclamationmark.triangle.fill")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.orange.opacity(0.9), in: Capsule())
                                .padding(.bottom, 8)
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
