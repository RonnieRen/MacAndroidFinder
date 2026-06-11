import Foundation

// MARK: - TransferQueueStore
//
// Unified sequential transfer worker for uploads (Mac → phone) and downloads
// (phone → Mac). Replaces the old UploadQueueStore. Tracks per-task progress
// and speed for the transfer popover, and supports cancelling both queued
// and in-flight tasks (in-flight cancellation terminates the adb process).

@MainActor
final class TransferQueueStore: ObservableObject {
    @Published var tasks: [TransferTaskItem] = []
    @Published var isTransferring = false

    var onStatus: ((String, String?) -> Void)?
    /// Remote directories touched by completed uploads (refresh listings).
    var onUploadsCompleted: ((Set<String>) -> Void)?

    private let bridgeService: DroidADBService
    private var workerTask: Task<Void, Never>?
    private var deviceSerial: String?
    private var cancelTokens: [UUID: TransferCancelToken] = [:]

    init(bridgeService: DroidADBService) {
        self.bridgeService = bridgeService
    }

    // MARK: - Summary (status bar / popover header)

    var runningCount: Int { tasks.filter { $0.status == .running }.count }
    var pendingCount: Int { tasks.filter { $0.status == .pending }.count }
    var finishedCount: Int { tasks.filter(\.isFinished).count }
    var activeCount: Int { runningCount + pendingCount }

    var currentSpeed: Double? {
        tasks.first(where: { $0.status == .running })?.speedBytesPerSec
    }

    /// Overall fraction including the running task's partial progress.
    var overallProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        let done = Double(finishedCount)
        let current = tasks.first(where: { $0.status == .running })?.progress ?? 0
        return (done + current) / Double(tasks.count)
    }

    // MARK: - Enqueue

    func enqueueUploads(urls: [URL], remoteDirectory: String, deviceSerial: String?) {
        guard !urls.isEmpty, let deviceSerial else { return }
        let items = urls.map { url in
            TransferTaskItem(
                direction: .upload,
                fileName: url.lastPathComponent,
                destinationDisplay: Self.displayRemote(remoteDirectory),
                totalBytes: Self.localFileSize(url),
                localURL: url,
                remotePath: remoteDirectory
            )
        }
        tasks.append(contentsOf: items)
        startWorkerIfNeeded(deviceSerial: deviceSerial)
    }

    func enqueueDownloads(items: [DroidFileItem], to localDirectory: URL, deviceSerial: String?) {
        guard !items.isEmpty, let deviceSerial else { return }
        let newTasks = items.map { item in
            TransferTaskItem(
                direction: .download,
                fileName: item.name,
                destinationDisplay: Self.displayLocal(localDirectory),
                totalBytes: Int64(item.sizeDescription),
                localURL: localDirectory,
                remotePath: item.fullPath
            )
        }
        tasks.append(contentsOf: newTasks)
        startWorkerIfNeeded(deviceSerial: deviceSerial)
    }

    // MARK: - Cancel / clear

    func cancel(taskID: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        switch tasks[idx].status {
        case .pending:
            tasks[idx].status = .cancelled
        case .running:
            cancelTokens[taskID]?.cancel()
        default:
            break
        }
    }

    func clearFinished() {
        tasks.removeAll(where: \.isFinished)
    }

    // MARK: - Worker

    private func startWorkerIfNeeded(deviceSerial serial: String) {
        deviceSerial = serial
        guard workerTask == nil else { return }
        workerTask = Task { [weak self] in
            await self?.processQueue()
        }
    }

    private func processQueue() async {
        isTransferring = true
        var touchedRemoteDirectories: Set<String> = []

        while let idx = tasks.firstIndex(where: { $0.status == .pending }) {
            guard let serial = deviceSerial else { break }

            tasks[idx].status = .running
            tasks[idx].progress = 0
            let task = tasks[idx]
            let token = TransferCancelToken()
            cancelTokens[task.id] = token

            do {
                try await run(task: task, serial: serial, token: token)
                update(task.id) {
                    $0.status = .completed
                    $0.progress = 1
                    $0.speedBytesPerSec = nil
                }
                if task.direction == .upload {
                    touchedRemoteDirectories.insert(task.remotePath)
                    onStatus?(L10n.uploaded(file: task.fileName), nil)
                } else {
                    onStatus?(L10n.downloadedFile(task.fileName), nil)
                }
            } catch DroidBridgeError.cancelled {
                update(task.id) {
                    $0.status = .cancelled
                    $0.speedBytesPerSec = nil
                }
            } catch {
                update(task.id) {
                    $0.status = .failed(error.localizedDescription)
                    $0.speedBytesPerSec = nil
                }
                onStatus?(
                    task.direction == .upload
                        ? L10n.uploadFailed(file: task.fileName)
                        : L10n.downloadFailed(),
                    error.localizedDescription
                )
            }
            cancelTokens[task.id] = nil
        }

        isTransferring = false
        workerTask = nil
        if !touchedRemoteDirectories.isEmpty {
            onUploadsCompleted?(touchedRemoteDirectories)
        }
    }

    private func run(task: TransferTaskItem, serial: String, token: TransferCancelToken) async throws {
        let bridge = bridgeService
        let taskID = task.id
        let totalBytes = task.totalBytes

        // Rolling speed estimate fed by the percent callback.
        let meter = SpeedMeter(totalBytes: totalBytes)
        let onPercent: (Int) -> Void = { [weak self] percent in
            let speed = meter.update(percent: percent)
            Task { @MainActor [weak self] in
                self?.update(taskID) {
                    $0.progress = Double(percent) / 100
                    if let speed { $0.speedBytesPerSec = speed }
                }
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    switch task.direction {
                    case .upload:
                        _ = task.localURL.startAccessingSecurityScopedResource()
                        defer { task.localURL.stopAccessingSecurityScopedResource() }
                        try bridge.pushFile(
                            deviceSerial: serial,
                            localFile: task.localURL,
                            remoteDirectory: task.remotePath,
                            onPercent: onPercent,
                            cancelToken: token
                        )
                    case .download:
                        try bridge.pullFile(
                            deviceSerial: serial,
                            remotePath: task.remotePath,
                            localDirectory: task.localURL,
                            onPercent: onPercent,
                            cancelToken: token
                        )
                    }
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func update(_ id: UUID, _ mutate: (inout TransferTaskItem) -> Void) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        mutate(&tasks[idx])
    }

    // MARK: - Helpers

    private static func localFileSize(_ url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map(Int64.init)
    }

    private static func displayLocal(_ url: URL) -> String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private static func displayRemote(_ path: String) -> String {
        var p = path
        if p.hasPrefix("/") { p.removeFirst() }
        return p
    }
}

// MARK: - SpeedMeter

/// Thread-safe rolling speed estimator driven by percent callbacks.
private final class SpeedMeter: @unchecked Sendable {
    private let lock = NSLock()
    private let totalBytes: Int64?
    private var lastTime = Date()
    private var lastPercent = 0
    private var smoothed: Double?

    init(totalBytes: Int64?) {
        self.totalBytes = totalBytes
    }

    /// Returns the updated bytes/sec estimate, or nil when not computable.
    func update(percent: Int) -> Double? {
        guard let totalBytes else { return nil }
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let dt = now.timeIntervalSince(lastTime)
        let dp = percent - lastPercent
        guard dt > 0.2, dp > 0 else { return smoothed }

        let bytes = Double(totalBytes) * Double(dp) / 100
        let instant = bytes / dt
        smoothed = smoothed.map { $0 * 0.6 + instant * 0.4 } ?? instant
        lastTime = now
        lastPercent = percent
        return smoothed
    }
}
