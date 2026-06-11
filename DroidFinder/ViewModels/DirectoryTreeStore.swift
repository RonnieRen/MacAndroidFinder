import Foundation

// MARK: - DirectoryTreeStore
//
// Owns the left-sidebar directory tree. Caches child directories per path and
// loads them lazily off the main thread via the underlying ADB service.

@MainActor
final class DirectoryTreeStore: ObservableObject {
    @Published var directoryTreeRoots: [RemoteDirectoryNode] = []

    private let bridgeService: DroidADBService
    private var selectedDeviceSerial: String?
    /// Published so the sidebar re-renders when lazily-loaded children arrive.
    @Published private var directoryChildrenCache: [String: [RemoteDirectoryNode]] = [:]
    @Published private var loadingDirectoryPaths: Set<String> = []

    init(bridgeService: DroidADBService) {
        self.bridgeService = bridgeService
    }

    func configureForDevice(serial: String?) {
        selectedDeviceSerial = serial
        directoryChildrenCache.removeAll()
        loadingDirectoryPaths.removeAll()

        guard serial != nil else {
            directoryTreeRoots = []
            return
        }

        directoryTreeRoots = [
            RemoteDirectoryNode(path: "/sdcard", name: "sdcard", autoExpand: true)
        ]

        for root in directoryTreeRoots {
            ensureLoaded(path: root.path)
        }
    }

    func childrenForDirectory(path: String) -> [RemoteDirectoryNode] {
        directoryChildrenCache[path] ?? []
    }

    func isDirectoryLoading(path: String) -> Bool {
        loadingDirectoryPaths.contains(path)
    }

    func ensureLoaded(path: String, forceRefresh: Bool = false) {
        guard selectedDeviceSerial != nil else { return }

        if forceRefresh {
            directoryChildrenCache.removeValue(forKey: path)
        }
        guard directoryChildrenCache[path] == nil else { return }
        guard !loadingDirectoryPaths.contains(path) else { return }

        loadingDirectoryPaths.insert(path)

        Task {
            defer { loadingDirectoryPaths.remove(path) }
            do {
                let children = try await loadSubdirectories(path: path)
                directoryChildrenCache[path] = children
            } catch {
                directoryChildrenCache[path] = []
            }
        }
    }

    private func loadSubdirectories(path: String) async throws -> [RemoteDirectoryNode] {
        guard let serial = selectedDeviceSerial else { return [] }
        let items = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.bridgeService.listDirectory(deviceSerial: serial, path: path)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return items
            .filter(\.isDirectory)
            .map { item in
                RemoteDirectoryNode(path: item.fullPath, name: item.name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
