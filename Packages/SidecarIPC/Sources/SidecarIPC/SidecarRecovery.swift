import Foundation
import LLMClient

public enum SidecarRecovery {
    public static func isRecoverable(_ error: Error) -> Bool {
        if let ipc = error as? SidecarIPCError {
            switch ipc {
            case .notConnected, .sidecarCrashed, .timeout:
                return true
            case .invalidLine, .pathTooLong:
                return false
            }
        }
        if let launch = error as? SidecarLaunchError {
            switch launch {
            case .notReady, .launchFailed:
                return true
            case .helperMissing:
                return false
            }
        }
        return false
    }

    public static func message(sidecarName: String, error: Error) -> String {
        if (error as? SidecarLaunchError) == .helperMissing {
            return "\(sidecarName) sidecar missing. Rebuild with bash Scripts/build_app.sh"
        }
        if isRecoverable(error) {
            return "\(sidecarName) sidecar stopped. Retry to restart it."
        }
        if case LLMClientError.httpStatus(let code, _) = error {
            return code == 401 ? "Invalid API key." : "Request failed (\(code))."
        }
        return error.localizedDescription
    }
}
