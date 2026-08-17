import Foundation
import Telemetry

enum LaunchTiming {
    static let processStart = CFAbsoluteTimeGetCurrent()

    @MainActor
    static func markComposerReady(telemetry: Telemetry) {
        let ms = (CFAbsoluteTimeGetCurrent() - processStart) * 1000
        try? telemetry.record(PerfEvent(kind: .coldStart, durationMs: ms))
    }
}
