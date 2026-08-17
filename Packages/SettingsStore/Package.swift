// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SettingsStore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SettingsStore", targets: ["SettingsStore"]),
    ],
    targets: [
        .target(name: "SettingsStore"),
        .testTarget(name: "SettingsStoreTests", dependencies: ["SettingsStore"]),
    ]
)
