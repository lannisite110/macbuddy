import SwiftUI

struct ChatPanelView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var composerFocused: Bool
    @State private var draft = ""
    let onComposerReady: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SessionListView()
                .frame(height: 120)
            Divider()
            TextEditor(text: $draft)
                .font(.body)
                .focused($composerFocused)
                .padding(8)
                .accessibilityIdentifier("composer")
        }
        .onAppear {
            LaunchTiming.markComposerReady(telemetry: appState.telemetry)
            onComposerReady()
            composerFocused = true
        }
    }
}
