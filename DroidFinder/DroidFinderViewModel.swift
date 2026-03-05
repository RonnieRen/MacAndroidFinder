import AppKit
import Foundation

struct RemoteDirectoryNode: Identifiable, Hashable {
    let path: String
    let name: String

    var id: String { path }
}

enum UploadTaskStatus: String {
    case pending = "等待中"
    case uploading = "上传中"
    case completed = "已完成"
    case failed = "失败"
}

struct UploadTaskItem: Identifiable {
    let id = UUID()
    let localURL: URL
    let remoteDirectory: String
    var status: UploadTaskStatus
    var detail: String?

    var fileName: String {
        localURL.lastPathComponent
    }
}

@MainActor
final class DirectoryTreeStore: ObservableObject {
    @Published var directoryTreeRoots: [RemoteDirectoryNode] = []

    private let bridgeService: DroidADBService
    private var selectedDeviceSerial: String?
    private var directoryChildrenCache: [String: [RemoteDirectoryNode]] = [:]
    private var loadingDirectoryPaths: Set<String> = []

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
            RemoteDirectoryNode(path: "/", name: "/"),
            RemoteDirectoryNode(path: "/sdcard", name: "Phone"),
            RemoteDirectoryNode(path: "/sdcard/DCIM/Camera", name: "Camera")
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

@MainActor
final class UploadQueueStore: ObservableObject {
    @Published var uploadQueue: [UploadTaskItem] = []
    @Published var uploadProgress: Double = 0
    @Published var isUploading = false

    var onStatus: ((String, String?) -> Void)?
    var onBatchCompleted: ((Set<String>) -> Void)?

    private let bridgeService: DroidADBService
    private var workerTask: Task<Void, Never>?

    init(bridgeService: DroidADBService) {
        self.bridgeService = bridgeService
    }

    func enqueue(urls: [URL], remoteDirectory: String, deviceSerial: String?) {
        guard !urls.isEmpty else { return }
        guard deviceSerial != nil else { return }

        let items = urls.map { url in
            UploadTaskItem(localURL: url, remoteDirectory: remoteDirectory, status: .pending, detail: nil)
        }
        uploadQueue.append(contentsOf: items)
        recalcProgress()
        startWorkerIfNeeded(deviceSerial: deviceSerial)
    }

    func clearFinished() {
        uploadQueue.removeAll { $0.status == .completed || $0.status == .failed }
        recalcProgress()
    }

    private func startWorkerIfNeeded(deviceSerial: String?) {
        guard workerTask == nil else { return }
        guard let serial = deviceSerial else { return }

        workerTask = Task { [weak self] in
            await self?.processQueue(deviceSerial: serial)
        }
    }

    private func processQueue(deviceSerial: String) async {
        isUploading = true
        var touchedDirectories: Set<String> = []

        while let idx = uploadQueue.firstIndex(where: { $0.status == .pending }) {
            uploadQueue[idx].status = .uploading
            uploadQueue[idx].detail = nil

            let task = uploadQueue[idx]
            do {
                try await pushFileAsync(deviceSerial: deviceSerial, localURL: task.localURL, remoteDirectory: task.remoteDirectory)
                uploadQueue[idx].status = .completed
                uploadQueue[idx].detail = "上传完成"
                touchedDirectories.insert(task.remoteDirectory)
                onStatus?("已上传：\(task.fileName)", nil)
            } catch {
                uploadQueue[idx].status = .failed
                uploadQueue[idx].detail = error.localizedDescription
                onStatus?("上传失败：\(task.fileName)", error.localizedDescription)
            }

            recalcProgress()
        }

        isUploading = false
        workerTask = nil
        onBatchCompleted?(touchedDirectories)
    }

    private func pushFileAsync(deviceSerial: String, localURL: URL, remoteDirectory: String) async throws {
        let uploadBridgeService = self.bridgeService
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                _ = localURL.startAccessingSecurityScopedResource()
                defer { localURL.stopAccessingSecurityScopedResource() }

                do {
                    try uploadBridgeService.pushFile(deviceSerial: deviceSerial, localFile: localURL, remoteDirectory: remoteDirectory)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func recalcProgress() {
        guard !uploadQueue.isEmpty else {
            uploadProgress = 0
            return
        }
        let doneCount = uploadQueue.filter { $0.status == .completed || $0.status == .failed }.count
        uploadProgress = Double(doneCount) / Double(uploadQueue.count)
    }
}

@MainActor
final class DroidFinderViewModel: ObservableObject {
    @Published var devices: [DroidDevice] = []
    @Published var selectedDevice: DroidDevice?
    @Published var currentPath: String = "/sdcard"
    @Published var files: [DroidFileItem] = []
    @Published var statusMessage: String = "准备就绪"
    @Published var errorMessage: String?
    @Published var isBusy = false

    let directoryTreeStore: DirectoryTreeStore
    let uploadQueueStore: UploadQueueStore

    private let bridgeService: DroidADBService

    init() {
        let service = DroidADBService()
        self.bridgeService = service
        self.directoryTreeStore = DirectoryTreeStore(bridgeService: service)
        self.uploadQueueStore = UploadQueueStore(bridgeService: service)

        uploadQueueStore.onStatus = { [weak self] message, error in
            self?.statusMessage = message
            self?.errorMessage = error
        }

        uploadQueueStore.onBatchCompleted = { [weak self] touchedDirectories in
            guard let self else { return }
            for path in touchedDirectories {
                self.directoryTreeStore.ensureLoaded(path: path, forceRefresh: true)
            }
            try? self.loadDirectory(path: self.currentPath)
        }

        Task {
            await refreshDevices()
        }
    }

    func refreshDevices() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try bridgeService.checkBridgeReady()
            let bridgeInfo = bridgeService.bridgeToolPath.map { "adb: \($0)" } ?? "adb: 未找到"
            let listed = try bridgeService.listDevices().filter { $0.transportState == "device" }
            devices = listed

            if let selectedDevice, !listed.contains(selectedDevice) {
                self.selectedDevice = nil
            }

            if self.selectedDevice == nil {
                self.selectedDevice = listed.first
            }

            directoryTreeStore.configureForDevice(serial: self.selectedDevice?.id)

            if self.selectedDevice != nil {
                try loadDirectory(path: currentPath)
            } else {
                files = []
                statusMessage = "没有可用设备（\(bridgeInfo)）。请连接手机并开启 USB 调试。"
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "无法读取设备。"
        }
    }

    func loadDirectory(path: String) throws {
        guard let selectedDevice else {
            files = []
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            files = try bridgeService.listDirectory(deviceSerial: selectedDevice.id, path: path)
            currentPath = path
            statusMessage = "已加载 \(files.count) 项"
            errorMessage = nil
            directoryTreeStore.ensureLoaded(path: path)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "目录读取失败"
            throw error
        }
    }

    func goParent() {
        guard currentPath != "/" else { return }
        let parent = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
        do {
            try loadDirectory(path: parent.isEmpty ? "/" : parent)
        } catch {
            // Error already set in loadDirectory
        }
    }

    func download(_ item: DroidFileItem) {
        guard !item.isDirectory else { return }
        guard let selectedDevice else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择下载目录"

        guard panel.runModal() == .OK, let targetDir = panel.url else {
            return
        }

        isBusy = true
        Task {
            do {
                try bridgeService.pullFile(deviceSerial: selectedDevice.id, remotePath: item.fullPath, localDirectory: targetDir)
                statusMessage = "已下载：\(item.name)"
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "下载失败"
            }
            isBusy = false
        }
    }

    func chooseAndUploadFiles(to remoteDirectory: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = "上传到 \(remoteDirectory)"

        guard panel.runModal() == .OK else { return }
        uploadLocalFiles(panel.urls, to: remoteDirectory)
    }

    func uploadLocalFiles(_ urls: [URL], to remoteDirectory: String) {
        uploadQueueStore.enqueue(urls: urls, remoteDirectory: remoteDirectory, deviceSerial: selectedDevice?.id)
    }
}
