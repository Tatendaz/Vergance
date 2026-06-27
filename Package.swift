// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GazeKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "GazeKit", targets: ["GazeKit"]),
    ],
    targets: [
        .target(name: "GazeKit"),
        .testTarget(name: "GazeKitTests", dependencies: ["GazeKit"]),
    ]
)
