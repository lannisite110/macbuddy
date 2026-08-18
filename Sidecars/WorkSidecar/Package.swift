// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WorkSidecar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacBuddyWork", targets: ["WorkSidecar"]),
    ],
    dependencies: [
        .package(path: "../../Packages/SidecarIPC"),
        .package(path: "../../Packages/WorkSkills"),
        .package(path: "../../Packages/LLMClient"),
    ],
    targets: [
        .executableTarget(
            name: "WorkSidecar",
            dependencies: ["SidecarIPC", "WorkSkills", "LLMClient"],
            path: "Sources/WorkSidecar"
        ),
    ]
)
