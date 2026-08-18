import Foundation
import SidecarIPC

let socketPath: String
if let index = CommandLine.arguments.firstIndex(of: "--socket"), index + 1 < CommandLine.arguments.count {
    socketPath = CommandLine.arguments[index + 1]
} else {
    socketPath = SidecarPaths.codeSocketURL().path
}

do {
    try CodeSidecarServer(socketPath: socketPath).run()
} catch {
    fputs("MacBuddyCode failed: \(error)\n", stderr)
    exit(1)
}
