// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PluginHost",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginHost", targets: ["PluginHost"]),
    ],
    targets: [
        .target(name: "PluginHost"),
        .testTarget(name: "PluginHostTests", dependencies: ["PluginHost"]),
    ]
)
