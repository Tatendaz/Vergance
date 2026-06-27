import AVFoundation
import GazeKit
import SwiftUI

/// Phase 1 probe + Phase 2 calibration/run, switched by a segmented mode picker. The
/// probe screen below is unchanged from Phase 1; Calibrate and Run are new.
struct ContentView: View {
    @StateObject private var model = ProbeViewModel()
    @StateObject private var calibration = CalibrationViewModel()
    @State private var mode: AppMode = .probe

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: modeBinding) {
                Text("Probe").tag(AppMode.probe)
                Text("Calibrate").tag(AppMode.calibrate)
                Text("Run").tag(AppMode.run)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            .padding(8)
            .disabled(calibration.isCalibrating)

            Divider()

            modeContent
        }
        .frame(minWidth: 760, minHeight: 460)
        .onChange(of: mode) { _, newMode in
            Task { await switchTo(newMode) }
        }
    }

    /// Reject selecting Run until a calibration model exists ("Run disabled until calibrated").
    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { mode },
            set: { newValue in
                if newValue == .run, calibration.calibrationModel == nil { return }
                mode = newValue
            }
        )
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .probe:
            probeScreen
        case .calibrate:
            CalibrationView(calibration: calibration)
        case .run:
            GazeCursorView(calibration: calibration) { mode = .calibrate }
        }
    }

    /// Stop the activity we're leaving and start the one we're entering. Probe keeps its own
    /// Start/Stop button, so entering Probe only stops calibration/run.
    private func switchTo(_ newMode: AppMode) async {
        switch newMode {
        case .probe:
            calibration.stop()
        case .calibrate:
            model.stop()
            await calibration.enterCalibrateMode()
        case .run:
            model.stop()
            await calibration.enterRunMode()
        }
    }

    // MARK: Probe screen (Phase 1)

    private var probeScreen: some View {
        HStack(spacing: 0) {
            cameraArea
                .frame(minWidth: 480, minHeight: 360)

            Divider()

            readoutPanel
                .frame(width: 240)
                .padding()
        }
    }

    // MARK: Camera area

    @ViewBuilder
    private var cameraArea: some View {
        ZStack {
            Color.black

            switch model.authorization {
            case .denied, .restricted:
                permissionDenied
            default:
                if model.isRunning, let session = model.session {
                    CameraPreviewView(session: session, mirrored: model.mirrored)
                    if let landmarks = model.latestLandmarks {
                        LandmarkOverlay(
                            landmarks: landmarks,
                            gaze: model.gaze,
                            frameSize: model.frameSize,
                            mirrored: model.mirrored
                        )
                    }
                } else {
                    idlePlaceholder
                }
            }

            if let message = model.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding()
            }
        }
    }

    private var idlePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Press Start to open the webcam.")
                .foregroundStyle(.secondary)
        }
    }

    private var permissionDenied: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text("Camera access denied")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Enable it in System Settings → Privacy & Security → Camera, then restart the app.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: 320)
        }
        .padding()
    }

    // MARK: Readout panel

    private var readoutPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Webcam Probe")
                .font(.title3.weight(.semibold))

            Label(model.faceDetected ? "Face detected" : "No face",
                  systemImage: model.faceDetected ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(model.faceDetected ? .green : .secondary)

            Divider()

            Group {
                readout("Yaw", String(format: "%.1f°", degrees(model.headPose.yaw)))
                readout("Pitch", String(format: "%.1f°", degrees(model.headPose.pitch)))
                readout("Roll", String(format: "%.1f°", degrees(model.headPose.roll)))
                readout("gx", String(format: "%+.3f", model.gaze.x))
                readout("gy", String(format: "%+.3f", model.gaze.y))
                readout("MAR", String(format: "%.3f", model.mar))
                readout("FPS", String(format: "%.0f", model.fps))
            }
            .font(.system(.body, design: .monospaced))

            Spacer()

            Button(model.isRunning ? "Stop" : "Start") {
                Task {
                    if model.isRunning {
                        model.stop()
                    } else {
                        await model.start()
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func readout(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    private func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}

/// The three top-level screens.
enum AppMode: Hashable { case probe, calibrate, run }

#Preview {
    ContentView()
}
