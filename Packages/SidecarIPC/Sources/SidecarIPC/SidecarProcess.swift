import Foundation

public enum SidecarLaunchError: Error, Equatable {
    case helperMissing
    case launchFailed
    case notReady
}

public struct SidecarPaths {
    public static func socketsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacBuddy/Sockets", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    public static func llmSocketURL() -> URL {
        socketsDirectory().appendingPathComponent("llm.sock")
    }

    public static func workSocketURL() -> URL {
        socketsDirectory().appendingPathComponent("work.sock")
    }

    public static func codeSocketURL() -> URL {
        socketsDirectory().appendingPathComponent("code.sock")
    }

    public static func bundledHelper(named name: String) -> URL? {
        let envKeys: [String]
        switch name {
        case "MacBuddyLLM":
            envKeys = ["MACBUDDY_LLM_HELPER"]
        case "MacBuddyWork":
            envKeys = ["MACBUDDY_WORK_HELPER"]
        case "MacBuddyCode":
            envKeys = ["MACBUDDY_CODE_HELPER"]
        default:
            envKeys = ["MACBUDDY_HELPER"]
        }
        for key in envKeys {
            if let override = ProcessInfo.processInfo.environment[key],
               FileManager.default.isExecutableFile(atPath: override) {
                return URL(fileURLWithPath: override)
            }
        }

        let bundle = Bundle.main.bundleURL
        let helper = bundle.appendingPathComponent("Contents/Helpers/\(name)")
        if FileManager.default.isExecutableFile(atPath: helper.path) {
            return helper
        }

        let sidecarDirs = ["LLMSidecar", "WorkSidecar", "CodeSidecar"]
        let roots = [
            bundle.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent(),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        ]
        for root in roots {
            for sidecarDir in sidecarDirs {
                let dev = root.appendingPathComponent("Sidecars/\(sidecarDir)/.build/debug/\(name)")
                if FileManager.default.isExecutableFile(atPath: dev.path) {
                    return dev
                }
            }
        }
        return nil
    }
}

public actor SidecarProcess {
    private var process: Process?
    private let helperName: String
    private let socketURL: URL

    public init(helperName: String, socketURL: URL) {
        self.helperName = helperName
        self.socketURL = socketURL
    }

    public func ensureRunning() throws -> String {
        if let process, process.isRunning {
            return socketURL.path
        }
        guard let helper = SidecarPaths.bundledHelper(named: helperName) else {
            throw SidecarLaunchError.helperMissing
        }
        try? FileManager.default.removeItem(at: socketURL)

        let launched = Process()
        launched.executableURL = helper
        launched.arguments = ["--socket", socketURL.path]
        launched.standardOutput = FileHandle.nullDevice
        launched.standardError = FileHandle.nullDevice
        try launched.run()
        process = launched
        return socketURL.path
    }

    public func terminate() {
        process?.terminate()
        process = nil
        try? FileManager.default.removeItem(at: socketURL)
    }

    public var isRunning: Bool {
        process?.isRunning ?? false
    }
}
