import AppKit
import GazeKit
import SwiftUI

/// Phase 2 calibration screen: a black field with one red target dot at a time at its
/// normalized position, a "Dot N / 9" progress label, and a capture animation (the dot
/// sits steady while settling, then shrinks and emits an expanding ring while capturing).
/// Reports its pixel size to the view model for `fit()`.
struct CalibrationView: View {
    @ObservedObject var calibration: CalibrationViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if calibration.cameraBlocked {
                    CameraIssueView(authorization: calibration.authorization,
                                    errorMessage: calibration.errorMessage)
                } else {
                    if let target = calibration.currentTarget {
                        TargetDot(capturing: calibration.isCapturing)
                            .position(x: target.x * geo.size.width,
                                      y: target.y * geo.size.height)
                    }

                    VStack {
                        header
                        Spacer()
                        controls
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAppear { report(geo.size) }
            .onChange(of: geo.size) { _, newSize in report(newSize) }
        }
    }

    /// Report the view's pixel size (points × backing scale) for `fit()`'s screenWidth/Height.
    private func report(_ size: CGSize) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        calibration.calibrationPixelSize = CGSize(width: size.width * scale,
                                                  height: size.height * scale)
    }

    // MARK: Pieces

    @ViewBuilder
    private var header: some View {
        switch calibration.calibrationState {
        case .running:
            VStack(spacing: 4) {
                Text("Dot \(calibration.currentDotIndex + 1) / \(calibration.targets.count)")
                    .font(.headline)
                Text(calibration.isCapturing ? "Capturing…" : "Settling…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
        case .done:
            Label("Calibration complete", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
        case .failed:
            Label("Calibration failed — retry", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.yellow)
        case .idle:
            Text("Look at each red dot until it stops pulsing.")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch calibration.calibrationState {
        case .running:
            Button(role: .cancel) { calibration.cancelCalibration() } label: {
                Text("Cancel").frame(maxWidth: 200)
            }
            .controlSize(.large)
        case .done:
            VStack(spacing: 8) {
                if let rms = calibration.rmsErrorPx {
                    Text(String(format: "RMS error: %.0f px", rms))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text("Switch to Run to use the gaze cursor.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
                Button("Recalibrate") { calibration.startCalibration() }
                    .controlSize(.large)
            }
        case .failed:
            Button("Retry") { calibration.startCalibration() }
                .controlSize(.large)
                .frame(maxWidth: 200)
        case .idle:
            Button("Start Calibration") { calibration.startCalibration() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .frame(maxWidth: 220)
                .disabled(!calibration.isRunning)
        }
    }
}

/// Red calibration target. Steady while settling; shrinks and emits an expanding "sonar"
/// ring while capturing, so the two phases are visually distinct. Honors Reduce Motion.
private struct TargetDot: View {
    let capturing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            if capturing && !reduceMotion {
                Circle()
                    .stroke(Color.red.opacity(0.7), lineWidth: 3)
                    .scaleEffect(pulse ? 2.4 : 1.0)
                    .opacity(pulse ? 0 : 0.8)
            }
            Circle()
                .fill(Color.red)
                .scaleEffect(capturing ? 0.65 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: capturing)
        }
        .frame(width: 28, height: 28)
        .shadow(color: .red.opacity(0.6), radius: 6)
        .onAppear(perform: restartPulse)
        .onChange(of: capturing) { _, _ in restartPulse() }
    }

    private func restartPulse() {
        pulse = false
        guard capturing, !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}
