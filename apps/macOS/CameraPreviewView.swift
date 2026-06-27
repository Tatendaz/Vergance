import AVFoundation
import SwiftUI

/// SwiftUI wrapper around an `AVCaptureVideoPreviewLayer`. Uses
/// `.resizeAspectFill` and mirrors the connection for front cameras so the
/// preview reads like a mirror — matched by `LandmarkOverlay`.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.configure(session: session, mirrored: mirrored)
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        nsView.configure(session: session, mirrored: mirrored)
    }
}

/// Layer-backed `NSView` that keeps its `AVCaptureVideoPreviewLayer` sized to
/// its bounds.
final class PreviewNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(session: AVCaptureSession, mirrored: Bool) {
        if previewLayer.session !== session {
            previewLayer.session = session
        }
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
