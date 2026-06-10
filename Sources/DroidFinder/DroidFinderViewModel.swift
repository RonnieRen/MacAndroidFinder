import AppKit
import Foundation

struct RemoteDirectoryNode: Identifiable, Hashable {
    let path: String
    let name: String
    var autoExpand: Bool = false

    var id: String { path }
}

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
            RemoteDirectoryNode(path: "/sdcard", name: L10n.phoneRoot()),
            RemoteDirectoryNode(path: "/sdcard/DCIM", name: "DCIM", autoExpand: true)
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
                uploadQueue[idx].detail = L10n.uploadDone()
                touchedDirectories.insert(task.remoteDirectory)
                onStatus?(L10n.uploaded(file: task.fileName), nil)
            } catch {
                uploadQueue[idx].status = .failed
                uploadQueue[idx].detail = error.localizedDescription
                onStatus?(L10n.uploadFailed(file: task.fileName), error.localizedDescription)
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
    @Published var wirelessServices: [WirelessService] = []
    @Published var statusMessage: String = L10n.ready()
    @Published var errorMessage: String?
    @Published var isBusy = false
    @Published var isWirelessBusy = false

    let directoryTreeStore: DirectoryTreeStore
    let uploadQueueStore: UploadQueueStore
    let imagePreviewService: ImagePreviewService

    private let bridgeService: DroidADBService
    private var deviceAutoRefreshTask: Task<Void, Never>?

    init() {
        let service = DroidADBService()
        self.bridgeService = service
        self.directoryTreeStore = DirectoryTreeStore(bridgeService: service)
        self.uploadQueueStore = UploadQueueStore(bridgeService: service)
        self.imagePreviewService = ImagePreviewService(bridge: service)

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
        startDeviceAutoRefresh()
    }

    func refreshDevices(showBusy: Bool = true, reloadCurrentDirectory: Bool = true) async {
        if showBusy {
            isBusy = true
        }
        defer {
            if showBusy {
                isBusy = false
            }
        }

        do {
            let previousSelectedDeviceID = selectedDevice?.id
            try bridgeService.checkBridgeReady()
            let bridgeInfo = L10n.adbPath(bridgeService.bridgeToolPath)
            let listed = try bridgeService.listDevices().filter { $0.transportState == "device" }
            devices = listed

            if let selectedDevice, !listed.contains(selectedDevice) {
                self.selectedDevice = nil
            }

            if self.selectedDevice == nil {
                self.selectedDevice = listed.first
            }

            let selectedDeviceChanged = previousSelectedDeviceID != self.selectedDevice?.id
            if selectedDeviceChanged || directoryTreeStore.directoryTreeRoots.isEmpty {
                directoryTreeStore.configureForDevice(serial: self.selectedDevice?.id)
            }

            if self.selectedDevice != nil {
                if reloadCurrentDirectory || selectedDeviceChanged || files.isEmpty {
                    try loadDirectory(path: currentPath, showBusy: false)
                }
            } else {
                files = []
                statusMessage = L10n.noDevice(bridgeInfo)
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = L10n.unableToReadDevice()
        }
    }

    func loadDirectory(path: String, showBusy: Bool = true) throws {
        guard let selectedDevice else {
            files = []
            return
        }

        if showBusy {
            isBusy = true
        }
        defer {
            if showBusy {
                isBusy = false
            }
        }

        do {
            files = try bridgeService.listDirectory(deviceSerial: selectedDevice.id, path: path)
            currentPath = path
            statusMessage = L10n.loadedItems(files.count)
            errorMessage = nil
            directoryTreeStore.ensureLoaded(path: path)
        } catch {
            if isPermissionDeniedError(error) {
                // Keep current view unchanged and avoid modal error alerts.
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
            statusMessage = L10n.directoryReadFailed()
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
        guard let selectedDevice else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.chooseDownloadDirectory()

        guard panel.runModal() == .OK, let targetDir = panel.url else {
            return
        }

        isBusy = true
        Task {
            do {
                try bridgeService.pullFile(deviceSerial: selectedDevice.id, remotePath: item.fullPath, localDirectory: targetDir)
                statusMessage = item.isDirectory ? L10n.downloadedDirectory(item.name) : L10n.downloadedFile(item.name)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = item.isDirectory ? L10n.downloadDirectoryFailed() : L10n.downloadFailed()
            }
            isBusy = false
        }
    }

    func chooseAndUploadFiles(to remoteDirectory: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = L10n.uploadTo(remoteDirectory)

        guard panel.runModal() == .OK else { return }
        uploadLocalFiles(panel.urls, to: remoteDirectory)
    }

    func uploadLocalFiles(_ urls: [URL], to remoteDirectory: String) {
        uploadQueueStore.enqueue(urls: urls, remoteDirectory: remoteDirectory, deviceSerial: selectedDevice?.id)
    }

    func delete(_ item: DroidFileItem) {
        guard let selectedDevice else { return }

        isBusy = true
        Task {
            do {
                try bridgeService.deletePath(deviceSerial: selectedDevice.id, remotePath: item.fullPath)
                statusMessage = item.isDirectory ? L10n.deletedFolder(item.name) : L10n.deletedFile(item.name)
                errorMessage = nil

                let parentPath = URL(fileURLWithPath: item.fullPath).deletingLastPathComponent().path
                directoryTreeStore.ensureLoaded(path: parentPath.isEmpty ? "/" : parentPath, forceRefresh: true)
                try? loadDirectory(path: currentPath, showBusy: false)
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = L10n.deleteFailed()
            }
            isBusy = false
        }
    }

    func delete(items: [DroidFileItem]) {
        guard let selectedDevice else { return }
        guard !items.isEmpty else { return }

        isBusy = true
        Task {
            var deletedCount = 0
            var lastError: Error?

            for item in items {
                do {
                    try bridgeService.deletePath(deviceSerial: selectedDevice.id, remotePath: item.fullPath)
                    deletedCount += 1
                } catch {
                    lastError = error
                }
            }

            if deletedCount > 0 {
                statusMessage = L10n.deletedItemsCount(deletedCount)
                errorMessage = nil
                directoryTreeStore.ensureLoaded(path: currentPath, forceRefresh: true)
                try? loadDirectory(path: currentPath, showBusy: false)
            }

            if let lastError {
                errorMessage = lastError.localizedDescription
                if deletedCount == 0 {
                    statusMessage = L10n.deleteFailed()
                }
            }

            isBusy = false
        }
    }

    func discoverWirelessServices() async {
        isWirelessBusy = true
        statusMessage = L10n.discoveringWireless()
        defer { isWirelessBusy = false }

        do {
            wirelessServices = try bridgeService.listWirelessServices()
            statusMessage = L10n.discoveredWirelessCount(wirelessServices.count)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func quickConnectSelectedDeviceViaWiFi() async {
        guard let selectedDevice, !selectedDevice.id.contains(":") else {
            errorMessage = L10n.noUSBDeviceSelected()
            return
        }

        isWirelessBusy = true
        defer { isWirelessBusy = false }

        do {
            let endpoint = try bridgeService.quickConnectFromUSB(deviceSerial: selectedDevice.id)
            statusMessage = L10n.connectedEndpoint(endpoint)
            errorMessage = nil
            await refreshDevices(showBusy: false, reloadCurrentDirectory: true)
            await discoverWirelessServices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectWireless(endpoint: String) async {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(":") else {
            errorMessage = L10n.invalidEndpoint()
            return
        }

        isWirelessBusy = true
        defer { isWirelessBusy = false }

        do {
            try bridgeService.connect(endpoint: trimmed)
            statusMessage = L10n.connectedEndpoint(trimmed)
            errorMessage = nil
            await refreshDevices(showBusy: false, reloadCurrentDirectory: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pairAndConnect(pairEndpoint: String, pairCode: String, connectEndpoint: String) async {
        let pairTarget = pairEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = pairCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let connectTarget = connectEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard pairTarget.contains(":"), connectTarget.contains(":"), !code.isEmpty else {
            errorMessage = L10n.invalidPairInput()
            return
        }

        isWirelessBusy = true
        defer { isWirelessBusy = false }

        do {
            try bridgeService.pair(endpoint: pairTarget, code: code)
            statusMessage = L10n.pairedEndpoint(pairTarget)
            try bridgeService.connect(endpoint: connectTarget)
            statusMessage = L10n.connectedEndpoint(connectTarget)
            errorMessage = nil
            await refreshDevices(showBusy: false, reloadCurrentDirectory: true)
            await discoverWirelessServices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnectWireless(endpoint: String?) async {
        isWirelessBusy = true
        defer { isWirelessBusy = false }

        do {
            let trimmed = endpoint?.trimmingCharacters(in: .whitespacesAndNewlines)
            try bridgeService.disconnect(endpoint: trimmed)
            if let trimmed, !trimmed.isEmpty {
                statusMessage = L10n.disconnectedEndpoint(trimmed)
            } else {
                statusMessage = L10n.disconnectedAll()
            }
            errorMessage = nil
            await refreshDevices(showBusy: false, reloadCurrentDirectory: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startDeviceAutoRefresh() {
        deviceAutoRefreshTask?.cancel()
        deviceAutoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self else { return }
                await self.refreshDevices(showBusy: false, reloadCurrentDirectory: false)
            }
        }
    }

    private func isPermissionDeniedError(_ error: Error) -> Bool {
        guard case let DroidBridgeError.commandFailed(message) = error else {
            return false
        }
        let lower = message.lowercased()
        return lower.contains("permission denied")
            || lower.contains("operation not permitted")
            || lower.contains("access denied")
    }
}
