import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - DroidFinderViewModel
//
// The top-level view model. Coordinates device discovery, directory
// navigation, file transfers and wireless ADB pairing. Most actions delegate
// to either `DroidADBService`, `DirectoryTreeStore`, or `TransferQueueStore`.

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

    /// Toolbar search — filters `displayedFiles` within the current folder.
    @Published var searchText = ""
    /// Battery / storage facts for the selected device (nil until fetched).
    @Published var deviceDetail: DeviceDetail?
    /// Browser-style navigation history.
    @Published private(set) var backStack: [String] = []
    @Published private(set) var forwardStack: [String] = []

    let directoryTreeStore: DirectoryTreeStore
    let transferQueueStore: TransferQueueStore
    let imagePreviewService: ImagePreviewService
    let thumbnailStore: ThumbnailStore

    let bridgeService: DroidADBService
    private var deviceAutoRefreshTask: Task<Void, Never>?
    private var deviceTrackerProcess: Process?

    private(set) lazy var qrPairingController: QRPairingController = {
        let controller = QRPairingController(bridgeService: bridgeService)
        controller.onConnected = { [weak self] endpoint in
            guard let self else { return }
            self.statusMessage = L10n.connectedEndpoint(endpoint)
            self.errorMessage = nil
            Task {
                await self.refreshDevices(showBusy: false, reloadCurrentDirectory: true)
                await self.discoverWirelessServices()
            }
        }
        return controller
    }()

    init() {
        let service = DroidADBService()
        self.bridgeService = service
        self.directoryTreeStore = DirectoryTreeStore(bridgeService: service)
        self.transferQueueStore = TransferQueueStore(bridgeService: service)
        self.imagePreviewService = ImagePreviewService(bridge: service)
        self.thumbnailStore = ThumbnailStore(bridge: service)

        transferQueueStore.onStatus = { [weak self] message, error in
            self?.statusMessage = message
            self?.errorMessage = error
        }

        transferQueueStore.onUploadsCompleted = { [weak self] touchedDirectories in
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

    // MARK: - Device discovery

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
            if selectedDeviceChanged {
                backStack = []
                forwardStack = []
                thumbnailStore.reset()
                deviceDetail = nil
            }
            if self.selectedDevice != nil, selectedDeviceChanged || deviceDetail == nil {
                refreshDeviceDetail()
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

    /// Fetch battery + storage info off the main actor.
    func refreshDeviceDetail() {
        guard let serial = selectedDevice?.id else { return }
        let br = bridgeService
        Task.detached(priority: .utility) { [weak self] in
            let detail = br.fetchDeviceDetail(deviceSerial: serial)
            await MainActor.run { [weak self] in
                guard let self, self.selectedDevice?.id == serial else { return }
                self.deviceDetail = detail
            }
        }
    }

    // MARK: - Directory navigation

    /// Files shown in the table: current directory filtered by the toolbar search.
    var displayedFiles: [DroidFileItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return files }
        return files.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// User-initiated navigation: records history, clears search.
    /// Returns false when the directory could not be loaded. `quiet` probing
    /// (quick-access candidates) suppresses the error alert on failure.
    @discardableResult
    func navigate(to path: String, quiet: Bool = false) -> Bool {
        guard path != currentPath else { return true }
        let previous = currentPath
        do {
            try loadDirectory(path: path, quiet: quiet)
            backStack.append(previous)
            forwardStack = []
            searchText = ""
            return true
        } catch {
            return false
        }
    }

    func goBack() {
        guard let target = backStack.popLast() else { return }
        let previous = currentPath
        do {
            try loadDirectory(path: target)
            forwardStack.append(previous)
            searchText = ""
        } catch {
            backStack.append(target)
        }
    }

    func goForward() {
        guard let target = forwardStack.popLast() else { return }
        let previous = currentPath
        do {
            try loadDirectory(path: target)
            backStack.append(previous)
            searchText = ""
        } catch {
            forwardStack.append(target)
        }
    }

    func loadDirectory(path: String, showBusy: Bool = true, quiet: Bool = false) throws {
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
            if path != currentPath {
                thumbnailStore.cancelPending()
            }
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
            if quiet {
                // Probing (quick-access candidates): no alert, just fail.
                throw error
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

    // MARK: - Download / upload

    func download(_ item: DroidFileItem) {
        download(items: [item])
    }

    /// Ask for a destination once, then queue every item as a download task.
    func download(items: [DroidFileItem]) {
        guard selectedDevice != nil, !items.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.chooseDownloadDirectory()
        guard panel.runModal() == .OK, let targetDir = panel.url else { return }

        transferQueueStore.enqueueDownloads(items: items, to: targetDir, deviceSerial: selectedDevice?.id)
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
        transferQueueStore.enqueueUploads(urls: urls, remoteDirectory: remoteDirectory, deviceSerial: selectedDevice?.id)
    }

    // MARK: - Delete

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

    // MARK: - Open in App (double-click)

    /// Pull the remote file to a local temp dir and open it with the system-default app.
    func openInApp(_ item: DroidFileItem) {
        guard let selectedDevice else { return }
        let serial = selectedDevice.id
        let br = bridgeService

        Task.detached(priority: .userInitiated) {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("DroidFinder", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let dest = tempDir.appendingPathComponent(item.name)

            do {
                // Remove stale copy if present
                try? FileManager.default.removeItem(at: dest)
                try br.pullFileToURL(deviceSerial: serial, remotePath: item.fullPath, localURL: dest)
                await MainActor.run {
                    NSWorkspace.shared.open(dest)
                    self.statusMessage = L10n.openedFile(item.name)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Temp file cleanup

    func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DroidFinder")
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Helpers

    private func startDeviceAutoRefresh() {
        deviceAutoRefreshTask?.cancel()
        deviceAutoRefreshTask = nil
        deviceTrackerProcess?.terminationHandler = nil
        deviceTrackerProcess?.terminate()

        // Preferred: `adb track-devices` long-lived connection — the adb
        // server pushes an update on every plug/unplug, no polling needed.
        deviceTrackerProcess = bridgeService.startDeviceTracking { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshDevices(showBusy: false, reloadCurrentDirectory: false)
            }
        }

        if let tracker = deviceTrackerProcess {
            // If the tracker dies (e.g. `adb kill-server`), restart after a beat.
            tracker.terminationHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self?.startDeviceAutoRefresh()
                }
            }
        } else {
            // adb missing or spawn failed — fall back to slow polling.
            deviceAutoRefreshTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    guard let self else { return }
                    await self.refreshDevices(showBusy: false, reloadCurrentDirectory: false)
                }
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
