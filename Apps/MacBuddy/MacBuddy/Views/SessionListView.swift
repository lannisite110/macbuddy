import SwiftUI
import SessionStore

struct SessionListView: View {
    @EnvironmentObject private var appState: AppState
    var onSelect: (UUID) -> Void = { _ in }
    var onNewChat: () -> Void = {}

    var body: some View {
        List(appState.sessions) { session in
            Text(session.title)
                .lineLimit(1)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(session.id)
                }
        }
        .listStyle(.sidebar)
        .overlay(alignment: .topTrailing) {
            Button("+") { onNewChat() }
                .buttonStyle(.borderless)
                .padding(6)
        }
    }
}
