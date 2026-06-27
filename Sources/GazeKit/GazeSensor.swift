import Foundation

/// A source of ``GazeSample``s.
///
/// Implemented per platform — `WebcamSensor` (macOS, AVFoundation + Vision) and
/// `TrueDepthSensor` (iOS, ARKit) — both of which live in their respective app targets so
/// this package stays dependency-free and headless-testable. Because every sensor emits
/// the same ``GazeSample``, backends are interchangeable and may run simultaneously.
public protocol GazeSensor: AnyObject {
    /// The live stream of samples. Consuming it more than once is implementation-defined.
    var samples: AsyncStream<GazeSample> { get }
    func start() async throws
    func stop()
}
