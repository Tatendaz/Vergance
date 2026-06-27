import GazeKit
import SwiftUI

/// Draws the detected landmarks over the camera preview: filled pupil dots,
/// eye-corner crosses, the outer-lip contour, and a raw (uncalibrated) gaze
/// point. Normalized top-left coordinates are mapped through the same
/// aspect-fill + mirroring as `CameraPreviewView` so the marks line up.
struct LandmarkOverlay: View {
    let landmarks: FaceLandmarks
    let gaze: CGPoint          // (gx, gy) raw pupil-offset feature
    let frameSize: CGSize      // pixel size of the source frame
    let mirrored: Bool

    var body: some View {
        Canvas { context, size in
            let map = Mapper(view: size, frame: frameSize, mirrored: mirrored)

            // Outer-lip contour.
            if landmarks.outerLips.count >= 2 {
                var path = Path()
                path.addLines(landmarks.outerLips.map { map.point($0) })
                path.closeSubpath()
                context.stroke(path, with: .color(.yellow.opacity(0.9)), lineWidth: 2)
            }

            // Eye corners as small crosses.
            for eye in [landmarks.leftEye, landmarks.rightEye] {
                drawCross(context, at: map.point(eye.innerCorner), color: .cyan)
                drawCross(context, at: map.point(eye.outerCorner), color: .cyan)
            }

            // Pupils as filled dots.
            for eye in [landmarks.leftEye, landmarks.rightEye] {
                let p = map.point(eye.pupil)
                let r: CGFloat = 4
                context.fill(
                    Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                    with: .color(.green)
                )
            }

            // Raw gaze point: midpoint between the pupils nudged by the gaze
            // feature. Uncalibrated — a direction indicator, not a screen target.
            let eyesMid = Point2D(
                x: (landmarks.leftEye.pupil.x + landmarks.rightEye.pupil.x) / 2,
                y: (landmarks.leftEye.pupil.y + landmarks.rightEye.pupil.y) / 2
            )
            let gazeScale = 0.4   // amplify the small normalized offset for visibility
            // Mirror the horizontal gaze nudge to match the mirrored preview, so the ring
            // follows your gaze (look left → ring left). Display-only — the gx feature
            // itself stays in true-image space for calibration.
            let gazeDX = (mirrored ? -gaze.x : gaze.x) * gazeScale
            let gazeNorm = Point2D(x: eyesMid.x + gazeDX, y: eyesMid.y + gaze.y * gazeScale)
            let gp = map.point(gazeNorm)
            let gr: CGFloat = 6
            context.stroke(
                Path(ellipseIn: CGRect(x: gp.x - gr, y: gp.y - gr, width: gr * 2, height: gr * 2)),
                with: .color(.red),
                lineWidth: 2
            )
        }
        .allowsHitTesting(false)
    }

    private func drawCross(_ context: GraphicsContext, at p: CGPoint, color: Color) {
        let s: CGFloat = 4
        var path = Path()
        path.move(to: CGPoint(x: p.x - s, y: p.y))
        path.addLine(to: CGPoint(x: p.x + s, y: p.y))
        path.move(to: CGPoint(x: p.x, y: p.y - s))
        path.addLine(to: CGPoint(x: p.x, y: p.y + s))
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
}

/// Maps an image-normalized, top-left `Point2D` into view pixels, replicating
/// the preview's `.resizeAspectFill` cropping and horizontal mirroring.
private struct Mapper {
    let view: CGSize
    let frame: CGSize
    let mirrored: Bool

    func point(_ p: Point2D) -> CGPoint {
        let frameAspect = frame.height > 0 ? frame.width / frame.height : 1
        let viewAspect = view.height > 0 ? view.width / view.height : 1

        var drawW = view.width
        var drawH = view.height
        if viewAspect > frameAspect {
            // View is wider: fill width, crop top/bottom.
            drawH = view.width / max(frameAspect, 0.0001)
        } else {
            // View is taller: fill height, crop sides.
            drawW = view.height * frameAspect
        }
        let offX = (view.width - drawW) / 2
        let offY = (view.height - drawH) / 2

        var x = offX + p.x * drawW
        let y = offY + p.y * drawH
        if mirrored { x = view.width - x }
        return CGPoint(x: x, y: y)
    }
}
