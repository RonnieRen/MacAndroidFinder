import Foundation

// MARK: - DroidFileItem

struct DroidFileItem: Identifiable, Hashable {
    enum ItemType {
        case file
        case directory
        case symlink
        case unknown
    }

    let id: String
    let name: String
    let fullPath: String
    let type: ItemType
    let sizeDescription: String
    let modifiedDate: Date?

    var isDirectory: Bool {
        type == .directory
    }
}
