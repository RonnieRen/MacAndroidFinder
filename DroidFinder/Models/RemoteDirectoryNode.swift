import Foundation

// MARK: - RemoteDirectoryNode

struct RemoteDirectoryNode: Identifiable, Hashable {
    let path: String
    let name: String
    var autoExpand: Bool = false

    var id: String { path }
}
