import Foundation

/// Quadratic ridge regression mapping raw 2-D gaze features to normalized screen points.
///
/// Feature row: `φ(g) = [1, gx, gy, gx·gy, gx², gy²]`. Two independent weight vectors
/// (x and y) are fit with ridge regularization, after centering/scaling the two inputs —
/// their squared terms are tiny and make `ΦᵀΦ` ill-conditioned otherwise.
public struct CalibrationModel: Sendable, Codable, Equatable {
    public var weightsX: [Double]   // 6
    public var weightsY: [Double]   // 6
    public var mean: [Double]       // 2 — input centering
    public var scale: [Double]      // 2 — input scaling

    public init(weightsX: [Double], weightsY: [Double], mean: [Double], scale: [Double]) {
        self.weightsX = weightsX
        self.weightsY = weightsY
        self.mean = mean
        self.scale = scale
    }

    /// Map a raw `(gx, gy)` feature pair to a normalized screen point.
    public func map(_ gx: Double, _ gy: Double) -> ScreenPoint {
        let phi = CalibrationModel.features(gx, gy, mean: mean, scale: scale)
        return ScreenPoint(x: dot(phi, weightsX), y: dot(phi, weightsY))
    }

    static func features(_ gx: Double, _ gy: Double, mean: [Double], scale: [Double]) -> [Double] {
        let nx = (gx - mean[0]) / scale[0]
        let ny = (gy - mean[1]) / scale[1]
        return [1, nx, ny, nx * ny, nx * nx, ny * ny]
    }
}

/// Accumulates calibration correspondences and fits a ``CalibrationModel``.
public struct CalibrationFitter {
    public struct Correspondence: Sendable, Equatable {
        public var gx, gy, sx, sy: Double
        public init(gx: Double, gy: Double, sx: Double, sy: Double) {
            self.gx = gx
            self.gy = gy
            self.sx = sx
            self.sy = sy
        }
    }

    public var ridge: Double
    public private(set) var points: [Correspondence] = []

    public init(ridge: Double = 1e-3) { self.ridge = ridge }

    public mutating func add(_ c: Correspondence) { points.append(c) }

    /// Fit two ridge-regularized quadratics. Returns `nil` if under-determined or singular.
    public func fit() -> CalibrationModel? {
        guard points.count >= 6 else { return nil }
        let gxs = points.map(\.gx)
        let gys = points.map(\.gy)
        let mean = [meanOf(gxs), meanOf(gys)]
        let scale = [stdOf(gxs, mean[0]), stdOf(gys, mean[1])].map { $0 == 0 ? 1 : $0 }

        let phi = points.map { CalibrationModel.features($0.gx, $0.gy, mean: mean, scale: scale) }
        let sx = points.map(\.sx)
        let sy = points.map(\.sy)
        guard let wx = ridgeSolve(phi: phi, target: sx, lambda: ridge),
              let wy = ridgeSolve(phi: phi, target: sy, lambda: ridge) else { return nil }
        return CalibrationModel(weightsX: wx, weightsY: wy, mean: mean, scale: scale)
    }
}

/// Solve `(ΦᵀΦ + λI) w = Φᵀ t` for `w`.
func ridgeSolve(phi: [[Double]], target: [Double], lambda: Double) -> [Double]? {
    let n = phi.count
    let k = phi.first?.count ?? 0
    guard n == target.count, k > 0 else { return nil }
    var a = Array(repeating: Array(repeating: 0.0, count: k), count: k)
    var b = Array(repeating: 0.0, count: k)
    for i in 0..<k {
        for j in 0..<k {
            var s = 0.0
            for r in 0..<n { s += phi[r][i] * phi[r][j] }
            a[i][j] = s
        }
        a[i][i] += lambda
        var s = 0.0
        for r in 0..<n { s += phi[r][i] * target[r] }
        b[i] = s
    }
    return solveLinearSystem(a: a, b: b)
}

/// Gaussian elimination with partial pivoting. Returns `nil` if singular.
func solveLinearSystem(a: [[Double]], b: [Double]) -> [Double]? {
    let n = b.count
    var m = a
    var v = b
    for col in 0..<n {
        var pivot = col
        var maxAbs = abs(m[col][col])
        for r in (col + 1)..<n where abs(m[r][col]) > maxAbs {
            maxAbs = abs(m[r][col])
            pivot = r
        }
        if maxAbs < 1e-12 { return nil }
        if pivot != col { m.swapAt(col, pivot); v.swapAt(col, pivot) }
        let pivVal = m[col][col]
        for r in (col + 1)..<n {
            let factor = m[r][col] / pivVal
            if factor == 0 { continue }
            for c in col..<n { m[r][c] -= factor * m[col][c] }
            v[r] -= factor * v[col]
        }
    }
    var x = Array(repeating: 0.0, count: n)
    for row in stride(from: n - 1, through: 0, by: -1) {
        var s = v[row]
        for c in (row + 1)..<n { s -= m[row][c] * x[c] }
        x[row] = s / m[row][row]
    }
    return x
}

func dot(_ a: [Double], _ b: [Double]) -> Double {
    zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
}

func meanOf(_ xs: [Double]) -> Double {
    xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count)
}

func stdOf(_ xs: [Double], _ m: Double) -> Double {
    guard xs.count > 1 else { return 1 }
    let variance = xs.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count)
    return variance.squareRoot()
}
