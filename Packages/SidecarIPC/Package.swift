// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SidecarIPC",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SidecarIPC", targets: ["SidecarIPC"]),
    ],
    dependencies: [
        .package(path: "../LLMClient"),
    ],
    targets: [
        .target(name: "SidecarIPC", dependencies: ["LLMClient"]),
        .testTarget(name: "SidecarIPCTests", dependencies: ["SidecarIPC"]),
    ]
)
