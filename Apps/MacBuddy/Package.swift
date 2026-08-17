// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacBuddy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacBuddy", targets: ["MacBuddy"]),
    ],
    dependencies: [
        .package(path: "../../Packages/SessionStore"),
        .package(path: "../../Packages/Telemetry"),
    ],
    targets: [
        .executableTarget(
            name: "MacBuddy",
            dependencies: ["SessionStore", "Telemetry"],
            path: "MacBuddy",
            exclude: ["Info.plist"]
        ),
    ]
)
