import SwiftUI

struct SessionListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(appState.sessions) { session in
            Text(session.title)
                .lineLimit(1)
        }
        .listStyle(.sidebar)
    }
}
