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
                    if let point = calibration.cursor {
                        GazeRing()
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
