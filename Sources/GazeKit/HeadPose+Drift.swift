import Foundation

public extension HeadPose {
    /// Angular distance to another pose, in radians — the Euclidean norm of the per-axis
    /// (yaw/pitch/roll) differences. A simple, monotonic metric for how far the head has
    /// drifted from the pose held at calibration; used to flag when accuracy has likely
    /// degraded and a recalibration is due.
    func angularDistance(to other: HeadPose) -> Double {
        let dyaw = yaw - other.yaw
        let dpitch = pitch - other.pitch
        let droll = roll - other.roll
        return (dyaw * dyaw + dpitch * dpitch + droll * droll).squareRoot()
    }
}
