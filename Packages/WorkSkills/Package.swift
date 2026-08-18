// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WorkSkills",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WorkSkills", targets: ["WorkSkills"]),
    ],
    dependencies: [
        .package(path: "../LLMClient"),
    ],
    targets: [
        .target(name: "WorkSkills", dependencies: ["LLMClient"]),
        .testTarget(name: "WorkSkillsTests", dependencies: ["WorkSkills", "LLMClient"]),
    ]
)
