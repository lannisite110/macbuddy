import CryptoKit
import Foundation

public enum PluginCapability: String, Codable, Sendable, CaseIterable {
    case network
    case fs
    case uiCommand = "ui.command"
}

public struct PluginManifest: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let entry: String
    public let sha256: String
    public let capabilities: [PluginCapability]

    public init(id: String, name: String, version: String, entry: String, sha256: String, capabilities: [PluginCapability]) {
        self.id = id
        self.name = name
        self.version = version
        self.entry = entry
        self.sha256 = sha256
        self.capabilities = capabilities
    }
}

public struct LoadedPlugin: Identifiable, Equatable, Sendable {
    public let manifest: PluginManifest
    public let directory: URL

    public var id: String { manifest.id }
}

public enum PluginHostError: Error, Equatable {
    case manifestMissing(String)
    case hashMismatch(String)
    case entryMissing(String)
}

public struct PluginHost: Sendable {
    public init() {}

    public func loadPlugins(from directory: URL) -> [LoadedPlugin] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var loaded: [LoadedPlugin] = []
        for dir in contents where dir.hasDirectoryPath {
            if let plugin = try? loadPlugin(at: dir) {
                loaded.append(plugin)
            }
        }
        return loaded.sorted { $0.manifest.name < $1.manifest.name }
    }

    public func loadPlugin(at directory: URL) throws -> LoadedPlugin {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PluginHostError.manifestMissing(directory.lastPathComponent)
        }
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
        let entryURL = directory.appendingPathComponent(manifest.entry)
        guard FileManager.default.fileExists(atPath: entryURL.path) else {
            throw PluginHostError.entryMissing(manifest.entry)
        }
        let entryData = try Data(contentsOf: entryURL)
        let hash = SHA256.hash(data: entryData).compactMap { String(format: "%02x", $0) }.joined()
        guard hash == manifest.sha256.lowercased() else {
            throw PluginHostError.hashMismatch(manifest.id)
        }
        return LoadedPlugin(manifest: manifest, directory: directory)
    }
}

public enum PluginHostPaths {
    public static func defaultDirectory(appSupport: URL) -> URL {
        appSupport.appendingPathComponent("Plugins", isDirectory: true)
    }
}
