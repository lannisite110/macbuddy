import Foundation
import Security

public struct ModelSettings: Codable, Equatable, Sendable {
    public var baseURL: String
    public var model: String

    public init(baseURL: String = "http://127.0.0.1:11434/v1", model: String = "llama3.2") {
        self.baseURL = baseURL
        self.model = model
    }
}

public enum SettingsStoreError: Error {
    case keychainFailed
}

public struct SettingsStore: Sendable {
    private static let prefsKey = "com.macbuddy.modelSettings"
    private static let keychainService = "com.macbuddy.app"
    private static let keychainAccount = "apiKey"

    public init() {}

    public func loadModelSettings() -> ModelSettings {
        guard
            let data = UserDefaults.standard.data(forKey: Self.prefsKey),
            let settings = try? JSONDecoder().decode(ModelSettings.self, from: data)
        else {
            return ModelSettings()
        }
        return settings
    }

    public func saveModelSettings(_ settings: ModelSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.prefsKey)
    }

    public func loadAPIKey() -> String? {
        KeychainHelper.load(service: Self.keychainService, account: Self.keychainAccount)
    }

    public func saveAPIKey(_ key: String) throws {
        guard KeychainHelper.save(key, service: Self.keychainService, account: Self.keychainAccount) else {
            throw SettingsStoreError.keychainFailed
        }
    }

    public func deleteAPIKey() {
        KeychainHelper.delete(service: Self.keychainService, account: Self.keychainAccount)
    }
}

enum KeychainHelper {
    static func save(_ value: String, service: String, account: String) -> Bool {
        delete(service: service, account: account)
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
