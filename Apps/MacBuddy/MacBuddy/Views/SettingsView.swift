import SwiftUI
import SettingsStore

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var baseURL = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var saveMessage = ""

    private let settingsStore = SettingsStore()

    var body: some View {
        TabView {
            Form {
                Text("MacBuddy P4")
                TextField("Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $model)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key (optional for local)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Default local: Ollama at http://127.0.0.1:11434/v1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .frame(width: 560, height: 420)
        .onAppear { load() }
    }

    private func load() {
        let settings = settingsStore.loadModelSettings()
        baseURL = settings.baseURL
        model = settings.model
        apiKey = settingsStore.loadAPIKey() ?? ""
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
}
