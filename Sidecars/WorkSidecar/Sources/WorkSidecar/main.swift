import Foundation
import SidecarIPC

let socketPath: String
if let index = CommandLine.arguments.firstIndex(of: "--socket"), index + 1 < CommandLine.arguments.count {
    socketPath = CommandLine.arguments[index + 1]
} else {
    socketPath = SidecarPaths.workSocketURL().path
}

do {
    try WorkSidecarServer(socketPath: socketPath).run()
} catch {
    fputs("MacBuddyWork failed: \(error)\n", stderr)
    exit(1)
}
