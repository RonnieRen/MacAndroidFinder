import Foundation

// MARK: - TransferTaskItem
//
// One row in the unified transfer queue (uploads AND downloads), backing the
// redesign's transfer popover.

struct TransferTaskItem: Identifiable {
    enum Direction {
        case upload      // Mac → phone
        case download    // phone → Mac
    }

    enum Status: Equatable {
        case pending
        case running
        case completed
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let direction: Direction
    let fileName: String
    /// Human-readable destination ("~/Downloads" or "sdcard/Documents").
    let destinationDisplay: String
    /// Known size in bytes (nil for folders / unknown).
    let totalBytes: Int64?

    // Execution payload.
    /// upload: local source file; download: local destination directory.
    let localURL: URL
    /// upload: remote target directory; download: remote source path.
    let remotePath: String

    var status: Status = .pending
    /// 0...1 while running.
    var progress: Double = 0
    /// Rolling estimate while running.
    var speedBytesPerSec: Double?

    var isFinished: Bool {
        switch status {
        case .completed, .failed, .cancelled: return true
        case .pending, .running: return false
        }
    }

    var transferredBytes: Int64? {
        totalBytes.map { Int64(Double($0) * progress) }
    }
}
