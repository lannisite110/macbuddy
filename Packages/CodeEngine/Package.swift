// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CodeEngine",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeEngine", targets: ["CodeEngine"]),
    ],
    dependencies: [
        .package(path: "../LLMClient"),
    ],
    targets: [
        .target(name: "CodeEngine", dependencies: ["LLMClient"]),
        .testTarget(name: "CodeEngineTests", dependencies: ["CodeEngine"]),
    ]
)
