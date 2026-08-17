import Foundation
import SidecarIPC

@main
enum LLMSidecarMain {
    static func main() {
        let socketPath: String
        if let index = CommandLine.arguments.firstIndex(of: "--socket"), index + 1 < CommandLine.arguments.count {
            socketPath = CommandLine.arguments[index + 1]
        } else {
            socketPath = SidecarPathsFallback.defaultSocket
        }

        let server = SidecarServer(socketPath: socketPath)
        do {
            try server.run()
        } catch {
            fputs("MacBuddyLLM failed: \(error)\n", stderr)
            exit(1)
        }
    }
}

private enum SidecarPathsFallback {
    static var defaultSocket: String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacBuddy/Sockets/llm.sock")
        return base.path
    }
}
