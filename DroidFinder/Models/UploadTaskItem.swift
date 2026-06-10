import Foundation

// MARK: - UploadTaskStatus

enum UploadTaskStatus: String {
    case pending
    case uploading
    case completed
    case failed

    var title: String {
        switch self {
        case .pending: return L10n.waiting()
        case .uploading: return L10n.uploading()
        case .completed: return L10n.completed()
        case .failed: return L10n.failed()
        }
    }
}

// MARK: - UploadTaskItem

struct UploadTaskItem: Identifiable {
    let id = UUID()
    let localURL: URL
    let remoteDirectory: String
    var status: UploadTaskStatus
    var detail: String?
    /// 0...1 transfer progress of this single file (only meaningful while `.uploading`).
    var progress: Double = 0

    var fileName: String {
        localURL.lastPathComponent
    }
}
