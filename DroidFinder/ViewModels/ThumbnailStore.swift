import AppKit
import Foundation

// MARK: - ThumbnailStore
//
// Lazy per-row thumbnails for the file table. Rows call `request` from
// `onAppear`; a single sequential worker pulls thumbnails over adb (MediaStore
// thumbnail when available, otherwise the original image for small files) and
// publishes them into `images`. Thumbnails are cached on disk between runs.

@MainActor
final class ThumbnailStore: ObservableObject {
    /// item.id (full remote path) → row thumbnail.
    @Published private(set) var images: [String: NSImage] = [:]

    private let bridge: DroidADBService
    private let cacheDir: URL
    private let maxPx: CGFloat = 120
    /// Skip original-image fallback above this size (bytes) to keep rows cheap.
    private let maxOriginalPullBytes = 12 * 1024 * 1024

    private var queue: [(item: DroidFileItem, serial: String)] = []
    private var requested: Set<String> = []
    private var isWorking = false
    private var generation = 0

    init(bridge: DroidADBService) {
        self.bridge = bridge
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = base.appendingPathComponent("DroidFinder/rowthumbs")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    /// Drop queued work (e.g. when navigating away); keeps loaded images.
    func cancelPending() {
        generation += 1
        queue.removeAll()
        requested.subtract(requested.filter { images[$0] == nil })
        isWorking = false
    }

    /// Full reset (device switch).
    func reset() {
        cancelPending()
        images.removeAll()
        requested.removeAll()
    }

    func request(item: DroidFileItem, deviceSerial: String) {
        guard ImagePreviewService.isImage(item.name),
              images[item.id] == nil,
              !requested.contains(item.id) else { return }
        requested.insert(item.id)
        queue.append((item, deviceSerial))
        startWorkerIfNeeded()
    }

    // MARK: - Worker

    private func startWorkerIfNeeded() {
        guard !isWorking else { return }
        isWorking = true
        let gen = generation

        Task { [weak self] in
            while let self, gen == self.generation, !self.queue.isEmpty {
                let (item, serial) = self.queue.removeFirst()
                let image = await self.fetch(item: item, serial: serial)
                guard gen == self.generation else { break }
                if let image {
                    self.images[item.id] = image
                }
            }
            self?.isWorking = false
        }
    }

    private func fetch(item: DroidFileItem, serial: String) async -> NSImage? {
        let cacheURL = cacheDir.appendingPathComponent(cacheKey(serial: serial, item: item) + ".jpg")
        if let cached = NSImage(contentsOf: cacheURL) {
            return cached
        }

        let br = bridge
        let maxPx = maxPx
        let sizeLimit = maxOriginalPullBytes

        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                // 1. MediaStore thumbnail (cheap).
                if let thumbPath = br.findAndroidThumbnailPath(deviceSerial: serial, remotePath: item.fullPath) {
                    let tmp = ImagePreviewService.tempURL(ext: "jpg")
                    defer { try? FileManager.default.removeItem(at: tmp) }
                    if (try? br.pullFileToURL(deviceSerial: serial, remotePath: thumbPath, localURL: tmp)) != nil,
                       let img = NSImage(contentsOf: tmp) {
                        let thumb = ImagePreviewService.resize(img, maxPx: maxPx)
                        ImagePreviewService.writeJPEG(thumb, to: cacheURL)
                        cont.resume(returning: thumb)
                        return
                    }
                }

                // 2. Pull the original only if it's small enough.
                if let bytes = Int(item.sizeDescription), bytes > sizeLimit {
                    cont.resume(returning: nil)
                    return
                }
                let ext = (item.name as NSString).pathExtension
                let tmp = ImagePreviewService.tempURL(ext: ext.isEmpty ? "bin" : ext)
                defer { try? FileManager.default.removeItem(at: tmp) }
                if (try? br.pullFileToURL(deviceSerial: serial, remotePath: item.fullPath, localURL: tmp)) != nil,
                   let img = NSImage(contentsOf: tmp) {
                    let thumb = ImagePreviewService.resize(img, maxPx: maxPx)
                    ImagePreviewService.writeJPEG(thumb, to: cacheURL)
                    cont.resume(returning: thumb)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private func cacheKey(serial: String, item: DroidFileItem) -> String {
        let raw = "rt|\(serial)|\(item.fullPath)|\(item.sizeDescription)"
        var h: UInt64 = 14695981039346656037
        for b in raw.utf8 { h ^= UInt64(b); h = h &* 1099511628211 }
        return String(format: "%016llx", h)
    }
}
