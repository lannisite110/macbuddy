import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            Form {
                Text("MacBuddy P0")
                Text("Hotkey: ⌘⇧Space")
            }
            .tabItem { Text("General") }

            PerformancePaneView()
                .environmentObject(appState)
                .tabItem { Text("Performance") }
        }
        .frame(width: 480, height: 320)
    }
}
