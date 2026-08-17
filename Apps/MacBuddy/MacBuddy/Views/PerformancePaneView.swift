import SwiftUI
import Telemetry

struct PerformancePaneView: View {
    @EnvironmentObject private var appState: AppState
    @State private var coldStarts: [PerfEvent] = []

    var body: some View {
        List(coldStarts, id: \.timestamp) { event in
            HStack {
                Text(event.timestamp.formatted())
                Spacer()
                Text(String(format: "%.0f ms", event.durationMs))
            }
        }
        .onAppear {
            coldStarts = (try? appState.telemetry.recentColdStarts(limit: 20)) ?? []
        }
    }
}
