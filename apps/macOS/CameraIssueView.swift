import AVFoundation
import SwiftUI

/// Shown on the Calibrate / Run screens when the camera can't run — permission denied or
/// restricted, or a start error — so those modes surface the reason instead of
/// dead-ending on a black field with a cursor that never moves.
struct CameraIssueView: View {
    let authorization: AVAuthorizationStatus
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text(isDenied ? "Camera access denied" : "Camera unavailable")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: 340)
        }
        .padding()
    }

    private var isDenied: Bool { authorization == .denied || authorization == .restricted }

    private var message: String {
        if let errorMessage { return errorMessage }
        return "Enable it in System Settings → Privacy & Security → Camera, then restart the app."
    }
}
