// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WorkflowTemplates",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WorkflowTemplates", targets: ["WorkflowTemplates"]),
    ],
    targets: [
        .target(name: "WorkflowTemplates"),
        .testTarget(name: "WorkflowTemplatesTests", dependencies: ["WorkflowTemplates"]),
    ]
)
