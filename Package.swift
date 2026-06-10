// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "GlassClock",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "GlassClockCore"),
        .executableTarget(name: "GlassClock", dependencies: ["GlassClockCore"]),
        .testTarget(name: "GlassClockCoreTests", dependencies: ["GlassClockCore"]),
    ]
)
