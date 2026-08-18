import Foundation

struct SidecarIssue: Equatable {
    let sidecarName: String
    let message: String
    let canRetry: Bool
}
