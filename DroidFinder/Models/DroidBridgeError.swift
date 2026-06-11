import Foundation

// MARK: - DroidBridgeError

enum DroidBridgeError: LocalizedError {
    case adbNotFound
    case commandFailed(String)
    case parseFailed
    case timedOut
    case cancelled

    var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return L10n.adbNotFound()
        case .commandFailed(let message):
            return message
        case .parseFailed:
            return L10n.parseDirectoryFailed()
        case .timedOut:
            return L10n.adbTimedOut()
        case .cancelled:
            return L10n.transferCancelled()
        }
    }
}
