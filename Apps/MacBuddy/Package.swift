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
        .package(path: "../../Packages/SettingsStore"),
        .package(path: "../../Packages/LLMClient"),
        .package(path: "../../Packages/LLMSidecarClient"),
        .package(path: "../../Packages/WorkSkills"),
        .package(path: "../../Packages/CodeEngine"),
        .package(path: "../../Packages/PluginHost"),
        .package(path: "../../Packages/WorkflowTemplates"),
    ],
    targets: [
        .executableTarget(
            name: "MacBuddy",
            dependencies: [
                "SessionStore", "Telemetry", "SettingsStore", "LLMClient", "LLMSidecarClient",
                "WorkSkills", "CodeEngine", "PluginHost", "WorkflowTemplates",
            ],
            path: "MacBuddy",
            exclude: ["Info.plist"]
        ),
    ]
)
