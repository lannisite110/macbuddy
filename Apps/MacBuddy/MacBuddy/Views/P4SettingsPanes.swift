import PluginHost
import SettingsStore
import SwiftUI
import WorkflowTemplates

struct FeaturesSettingsPane: View {
    @State private var features = FeatureSettings()
    @State private var saved = false
    private let settingsStore = SettingsStore()

    var body: some View {
        Form {
            Toggle("Incremental workspace index", isOn: $features.incrementalIndexEnabled)
            Text("Off by default. When enabled, re-scans only update changed files.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            TextField("Account email (optional)", text: $features.accountEmail)
            Stepper("Monthly quota remaining: \(features.monthlyQuotaRemaining)", value: $features.monthlyQuotaRemaining, in: 0...100_000)
            Button("Save") {
                settingsStore.saveFeatureSettings(features)
                saved = true
            }
            if saved {
                Text("Saved").font(.caption).foregroundStyle(.green)
            }
        }
        .padding()
        .onAppear { features = settingsStore.loadFeatureSettings() }
    }
}

struct WorkflowsSettingsPane: View {
    @ObservedObject private var workflows = WorkflowCoordinator.shared

    var body: some View {
        List(WorkflowCatalog.builtIn) { template in
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name).font(.headline)
                Text(template.description).font(.caption).foregroundStyle(.secondary)
                Button("Run") { workflows.run(template) }
                    .disabled(workflows.isRunning)
            }
            .padding(.vertical, 4)
        }
    }
}

struct PluginsSettingsPane: View {
    @ObservedObject private var plugins = PluginManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plugins directory:")
                .font(.caption)
            Text(plugins.pluginsDirectoryPath())
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            if plugins.plugins.isEmpty {
                Text("No plugins installed. Default install ships zero plugins.")
                    .foregroundStyle(.secondary)
            } else {
                List(plugins.plugins) { plugin in
                    VStack(alignment: .leading) {
                        Text(plugin.manifest.name)
                        Text(plugin.manifest.id).font(.caption).foregroundStyle(.secondary)
                        Text(plugin.manifest.capabilities.map(\.rawValue).joined(separator: ", "))
                            .font(.caption2)
                    }
                }
            }
            Button("Reload") {
                plugins.reload()
            }
        }
        .padding()
        .onAppear { plugins.loadIfNeeded() }
    }
}
