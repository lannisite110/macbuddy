// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LLMSidecarClient",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LLMSidecarClient", targets: ["LLMSidecarClient"]),
    ],
    dependencies: [
        .package(path: "../LLMClient"),
        .package(path: "../SidecarIPC"),
    ],
    targets: [
        .target(name: "LLMSidecarClient", dependencies: ["LLMClient", "SidecarIPC"]),
    ]
)
