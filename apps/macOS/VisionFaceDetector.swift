import CoreVideo
import GazeKit
import Vision

/// Runs `VNDetectFaceLandmarksRequest` on a `CVPixelBuffer` and maps the result
/// into GazeKit's `FaceLandmarks`.
///
/// Coordinate handling — the crux of this file:
/// Vision landmark points (`VNFaceLandmarkRegion2D.normalizedPoints`) are
/// normalized to the face `boundingBox`, with origin BOTTOM-LEFT. The bounding
/// box itself is normalized to the image, also origin bottom-left. So each
/// region point is converted to image-normalized coordinates with
/// `box.origin + point * box.size`, then the Y axis is flipped (`y' = 1 - y`)
/// to match GazeKit's top-left convention.
struct VisionFaceDetector {

    /// Detect the most prominent face and return its landmarks, or `nil` if no
    /// face (or no usable eye landmarks) was found. Runs synchronously on the
    /// caller's queue — call it from a background queue.
    func detect(in pixelBuffer: CVPixelBuffer) -> FaceLandmarks? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        // Prefer the largest face if several are present.
        guard let observation = request.results?.max(by: {
            ($0.boundingBox.width * $0.boundingBox.height) < ($1.boundingBox.width * $1.boundingBox.height)
        }) else { return nil }
        return Self.makeLandmarks(from: observation)
    }

    // MARK: Mapping

    private static func makeLandmarks(from observation: VNFaceObservation) -> FaceLandmarks? {
        guard let landmarks = observation.landmarks,
              let leftEyeRegion = landmarks.leftEye,
              let rightEyeRegion = landmarks.rightEye
        else { return nil }

        let box = observation.boundingBox
        // x is unaffected by the Y flip, so the face mid-line in image space is
        // simply the bounding-box centre x.
        let faceMidX = Double(box.midX)

        let leftEye = eye(from: leftEyeRegion, pupilRegion: landmarks.leftPupil, box: box, faceMidX: faceMidX)
        let rightEye = eye(from: rightEyeRegion, pupilRegion: landmarks.rightPupil, box: box, faceMidX: faceMidX)
        let outerLips = (landmarks.outerLips?.normalizedPoints ?? []).map { imagePoint($0, in: box) }
        let innerLips = (landmarks.innerLips?.normalizedPoints ?? []).map { imagePoint($0, in: box) }

        let pose = HeadPose(
            yaw: observation.yaw?.doubleValue ?? 0,
            pitch: observation.pitch?.doubleValue ?? 0,
            roll: observation.roll?.doubleValue ?? 0
        )

        return FaceLandmarks(leftEye: leftEye, rightEye: rightEye, outerLips: outerLips, innerLips: innerLips, headPose: pose)
    }

    /// Build one eye's landmarks: inner/outer corners from the extreme-x points
    /// of the eye region, and the pupil from the centroid of the pupil region.
    private static func eye(from region: VNFaceLandmarkRegion2D,
                            pupilRegion: VNFaceLandmarkRegion2D?,
                            box: CGRect,
                            faceMidX: Double) -> EyeLandmarks {
        let points = region.normalizedPoints.map { imagePoint($0, in: box) }
        let (inner, outer) = corners(of: points, faceMidX: faceMidX)
        let center = Point2D(x: (inner.x + outer.x) / 2, y: (inner.y + outer.y) / 2)
        let pupil = centroid(of: pupilRegion, in: box) ?? center
        return EyeLandmarks(innerCorner: inner, outerCorner: outer, pupil: pupil)
    }

    /// The inner corner is the extreme-x point nearer the face mid-line (towards
    /// the nose); the outer corner is the one farther away (towards the ear).
    /// This is robust to which image side each eye lands on and to mirroring.
    private static func corners(of points: [Point2D], faceMidX: Double) -> (inner: Point2D, outer: Point2D) {
        guard let minX = points.min(by: { $0.x < $1.x }),
              let maxX = points.max(by: { $0.x < $1.x })
        else { return (Point2D(x: faceMidX, y: 0), Point2D(x: faceMidX, y: 0)) }

        if abs(maxX.x - faceMidX) < abs(minX.x - faceMidX) {
            return (inner: maxX, outer: minX)
        } else {
            return (inner: minX, outer: maxX)
        }
    }

    private static func centroid(of region: VNFaceLandmarkRegion2D?, in box: CGRect) -> Point2D? {
        guard let region, !region.normalizedPoints.isEmpty else { return nil }
        let points = region.normalizedPoints.map { imagePoint($0, in: box) }
        let sx = points.reduce(0) { $0 + $1.x }
        let sy = points.reduce(0) { $0 + $1.y }
        let n = Double(points.count)
        return Point2D(x: sx / n, y: sy / n)
    }

    /// Convert a box-normalized, bottom-left point to an image-normalized,
    /// top-left `Point2D`.
    private static func imagePoint(_ p: CGPoint, in box: CGRect) -> Point2D {
        let ix = Double(box.origin.x) + Double(p.x) * Double(box.size.width)
        let iy = Double(box.origin.y) + Double(p.y) * Double(box.size.height)
        return Point2D(x: ix, y: 1 - iy)
    }
}
