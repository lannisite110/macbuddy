// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SessionStore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SessionStore", targets: ["SessionStore"]),
    ],
    targets: [
        .target(name: "SessionStore"),
        .testTarget(name: "SessionStoreTests", dependencies: ["SessionStore"]),
    ]
)
