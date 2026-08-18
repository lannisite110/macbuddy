// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CodeSidecarClient",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeSidecarClient", targets: ["CodeSidecarClient"]),
    ],
    dependencies: [
        .package(path: "../LLMClient"),
        .package(path: "../SidecarIPC"),
        .package(path: "../CodeEngine"),
    ],
    targets: [
        .target(name: "CodeSidecarClient", dependencies: ["LLMClient", "SidecarIPC", "CodeEngine"]),
    ]
)
