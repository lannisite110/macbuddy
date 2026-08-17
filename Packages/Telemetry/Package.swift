// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Telemetry",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Telemetry", targets: ["Telemetry"]),
    ],
    targets: [
        .target(name: "Telemetry"),
        .testTarget(name: "TelemetryTests", dependencies: ["Telemetry"]),
    ]
)
