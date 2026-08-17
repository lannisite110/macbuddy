// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LLMClient",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LLMClient", targets: ["LLMClient"]),
    ],
    targets: [
        .target(name: "LLMClient"),
        .testTarget(name: "LLMClientTests", dependencies: ["LLMClient"]),
    ]
)
