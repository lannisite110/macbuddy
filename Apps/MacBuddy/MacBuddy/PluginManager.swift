import Foundation
import PluginHost
import SettingsStore

@MainActor
final class PluginManager: ObservableObject {
    static let shared = PluginManager()

    @Published private(set) var plugins: [LoadedPlugin] = []
    @Published private(set) var loadErrors: [String] = []
    private var didLoad = false

    private init() {}

    func loadIfNeeded() {
        guard !didLoad else { return }
        reload()
        didLoad = true
    }

    func reload() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacBuddy", isDirectory: true)
        let pluginsDir = PluginHostPaths.defaultDirectory(appSupport: support)
        try? FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
        plugins = PluginHost().loadPlugins(from: pluginsDir)
    }

    func pluginsDirectoryPath() -> String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacBuddy", isDirectory: true)
        return PluginHostPaths.defaultDirectory(appSupport: support).path
    }
}
