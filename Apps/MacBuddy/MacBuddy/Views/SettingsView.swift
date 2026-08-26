import SwiftUI
import SettingsStore

private enum ModelProviderPreset: String, CaseIterable, Identifiable {
    case ollama
    case unsloth
    case openaiCompatible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ollama: return "Ollama"
        case .unsloth: return "Unsloth Desktop"
        case .openaiCompatible: return "Custom OpenAI-compatible"
        }
    }

    var baseURL: String {
        switch self {
        case .ollama: return "http://127.0.0.1:11434/v1"
        case .unsloth: return "http://127.0.0.1:8888/v1"
        case .openaiCompatible: return "http://127.0.0.1:11434/v1"
        }
    }

    var suggestedModel: String {
        switch self {
        case .ollama: return "llama3.2"
        case .unsloth: return "default"
        case .openaiCompatible: return "llama3.2"
        }
    }

    var help: String {
        switch self {
        case .ollama:
            return "Local Ollama. API key usually empty."
        case .unsloth:
            return "Start Unsloth Desktop, load a model, create sk-unsloth-… in Settings → API. Model id must match GET /v1/models (or try default)."
        case .openaiCompatible:
            return "Any OpenAI-compatible /v1 endpoint (gateway, llama.cpp, etc.)."
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var preset: ModelProviderPreset = .ollama
    @State private var baseURL = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var saveMessage = ""

    private let settingsStore = SettingsStore()

    var body: some View {
        TabView {
            Form {
                Text("MacBuddy P4")
                Picker("Provider", selection: $preset) {
                    ForEach(ModelProviderPreset.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .onChange(of: preset) { _, newValue in
                    applyPreset(newValue, overwriteModel: true)
                }

                TextField("Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $model)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key (Unsloth: sk-unsloth-…; Ollama usually empty)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                Text(preset.help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Save") { save() }
                    if !saveMessage.isEmpty {
                        Text(saveMessage).font(.caption).foregroundStyle(.green)
                    }
                }
            }
            .padding()
            .tabItem { Text("General") }

            FeaturesSettingsPane()
                .tabItem { Text("Features") }

            WorkflowsSettingsPane()
                .tabItem { Text("Workflows") }

            PluginsSettingsPane()
                .tabItem { Text("Plugins") }

            PerformancePaneView()
                .environmentObject(appState)
                .tabItem { Text("Performance") }
        }
        .frame(width: 560, height: 460)
        .onAppear { load() }
    }

    private func load() {
        let settings = settingsStore.loadModelSettings()
        baseURL = settings.baseURL
        model = settings.model
        apiKey = settingsStore.loadAPIKey() ?? ""
        preset = Self.inferPreset(baseURL: settings.baseURL)
    }

    private func applyPreset(_ value: ModelProviderPreset, overwriteModel: Bool) {
        baseURL = value.baseURL
        if overwriteModel {
            model = value.suggestedModel
        }
        saveMessage = ""
    }

    private func save() {
        settingsStore.saveModelSettings(ModelSettings(baseURL: baseURL, model: model))
        if apiKey.isEmpty {
            settingsStore.deleteAPIKey()
        } else {
            try? settingsStore.saveAPIKey(apiKey)
        }
        saveMessage = "Saved"
    }

    private static func inferPreset(baseURL: String) -> ModelProviderPreset {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.contains(":8888") { return .unsloth }
        if trimmed.contains(":11434") { return .ollama }
        return .openaiCompatible
    }
}
