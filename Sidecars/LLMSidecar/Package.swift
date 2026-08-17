// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LLMSidecar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacBuddyLLM", targets: ["LLMSidecar"]),
    ],
    dependencies: [
        .package(path: "../../Packages/SidecarIPC"),
    ],
    targets: [
        .executableTarget(name: "LLMSidecar", dependencies: ["SidecarIPC"], path: "Sources/LLMSidecar"),
    ]
)
