import Foundation
import SessionStore
import Telemetry

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let sessionStore: SessionStore
    let telemetry: Telemetry
    @Published var sessions: [SessionMetadata] = []

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacBuddy", isDirectory: true)
        sessionStore = try! SessionStore(databaseURL: support.appendingPathComponent("sessions.sqlite"))
        telemetry = Telemetry(directory: support.appendingPathComponent("Telemetry", isDirectory: true))
    }

    func loadSessionMetadata() {
        sessions = (try? sessionStore.fetchRecentSessionMetadata(limit: 50)) ?? []
    }
}
