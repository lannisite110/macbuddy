import Foundation
import Telemetry

enum LaunchTiming {
    private static var processStart: CFAbsoluteTime?
    private static var composerReadyRecorded = false

    static func markProcessStart() {
        if processStart == nil {
            processStart = CFAbsoluteTimeGetCurrent()
        }
    }

    @MainActor
    static func markComposerReady(telemetry: Telemetry) {
        guard !composerReadyRecorded else { return }
        composerReadyRecorded = true
        let start = processStart ?? CFAbsoluteTimeGetCurrent()
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        try? telemetry.record(PerfEvent(kind: .coldStart, durationMs: ms))
    }
}
