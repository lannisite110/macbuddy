import Foundation

enum BenchMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["MACBUDDY_BENCH"] == "1"
    }

    static var simulateHotkey: Bool {
        ProcessInfo.processInfo.environment["MACBUDDY_BENCH_HOTKEY"] == "1"
    }
}
