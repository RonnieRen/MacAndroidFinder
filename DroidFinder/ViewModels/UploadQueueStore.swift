import Foundation

// MARK: - UploadQueueStore
//
// Sequentially pushes a queue of local files to a remote directory via the
// ADB bridge service. Reports per-file status through `onStatus` and a
// post-batch summary through `onBatchCompleted`.

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
            uploadQueue[idx].progress = 0

            let task = uploadQueue[idx]
            let taskID = task.id
            do {
                try await pushFileAsync(
                    deviceSerial: deviceSerial,
                    localURL: task.localURL,
                    remoteDirectory: task.remoteDirectory,
                    onPercent: { [weak self] percent in
                        Task { @MainActor [weak self] in
                            self?.updateProgress(taskID: taskID, percent: percent)
                        }
                    }
                )
                // Items may have shifted while we were suspended (clearFinished) —
                // always re-resolve the index by id after the await.
                if let i = uploadQueue.firstIndex(where: { $0.id == taskID }) {
                    uploadQueue[i].status = .completed
                    uploadQueue[i].detail = L10n.uploadDone()
                    uploadQueue[i].progress = 1
                }
                touchedDirectories.insert(task.remoteDirectory)
                onStatus?(L10n.uploaded(file: task.fileName), nil)
            } catch {
                if let i = uploadQueue.firstIndex(where: { $0.id == taskID }) {
                    uploadQueue[i].status = .failed
                    uploadQueue[i].detail = error.localizedDescription
                }
                onStatus?(L10n.uploadFailed(file: task.fileName), error.localizedDescription)
            }

            recalcProgress()
        }

        isUploading = false
        workerTask = nil
        onBatchCompleted?(touchedDirectories)
    }

    private func pushFileAsync(
        deviceSerial: String,
        localURL: URL,
        remoteDirectory: String,
        onPercent: @escaping (Int) -> Void
    ) async throws {
        let uploadBridgeService = self.bridgeService
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                _ = localURL.startAccessingSecurityScopedResource()
                defer { localURL.stopAccessingSecurityScopedResource() }

                do {
                    try uploadBridgeService.pushFile(
                        deviceSerial: deviceSerial,
                        localFile: localURL,
                        remoteDirectory: remoteDirectory,
                        onPercent: onPercent
                    )
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func updateProgress(taskID: UUID, percent: Int) {
        guard let i = uploadQueue.firstIndex(where: { $0.id == taskID }) else { return }
        uploadQueue[i].progress = Double(percent) / 100
        recalcProgress()
    }

    private func recalcProgress() {
        guard !uploadQueue.isEmpty else {
            uploadProgress = 0
            return
        }
        let doneCount = uploadQueue.filter { $0.status == .completed || $0.status == .failed }.count
        let currentFraction = uploadQueue.first(where: { $0.status == .uploading })?.progress ?? 0
        uploadProgress = (Double(doneCount) + currentFraction) / Double(uploadQueue.count)
    }
}
