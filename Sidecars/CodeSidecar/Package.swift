// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CodeSidecar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacBuddyCode", targets: ["CodeSidecar"]),
    ],
    dependencies: [
        .package(path: "../../Packages/SidecarIPC"),
        .package(path: "../../Packages/CodeEngine"),
        .package(path: "../../Packages/LLMClient"),
    ],
    targets: [
        .executableTarget(
            name: "CodeSidecar",
            dependencies: ["SidecarIPC", "CodeEngine", "LLMClient"],
            path: "Sources/CodeSidecar"
        ),
    ]
)
