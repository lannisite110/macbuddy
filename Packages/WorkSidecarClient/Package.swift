// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WorkSidecarClient",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WorkSidecarClient", targets: ["WorkSidecarClient"]),
    ],
    dependencies: [
        .package(path: "../LLMClient"),
        .package(path: "../SidecarIPC"),
        .package(path: "../WorkSkills"),
    ],
    targets: [
        .target(name: "WorkSidecarClient", dependencies: ["LLMClient", "SidecarIPC", "WorkSkills"]),
    ]
)
