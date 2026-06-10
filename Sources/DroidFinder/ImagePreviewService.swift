import AppKit
import Foundation

@MainActor
final class ImagePreviewService: ObservableObject {
    @Published var previewImage: NSImage?
    @Published var isLoading = false
    @Published var previewError: String?

    private let bridge: DroidADBService
    private let cacheDir: URL
    private let maxCacheBytes = 500 * 1024 * 1024  // 500 MB
    private let thumbnailMaxPx: CGFloat = 1024

    private var debounceTask: Task<Void, Never>?
    private var activeItemID: String?

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif"
    ]

    init(bridge: DroidADBService) {
        self.bridge = bridge
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = base.appendingPathComponent("DroidFinder/previews")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    static func isImage(_ name: String) -> Bool {
        imageExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// 请求预览某个文件。选中非图片时传 nil 清除面板。
    func request(item: DroidFileItem, deviceSerial: String) {
        guard Self.isImage(item.name) else { reset(); return }
        guard item.id != activeItemID else { return }

        debounceTask?.cancel()
        activeItemID = item.id
        previewImage = nil
        previewError = nil
        isLoading = true

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)   // 1s debounce
            guard !Task.isCancelled else { return }
            await fetch(item: item, deviceSerial: deviceSerial)
        }
    }

    func reset() {
        debounceTask?.cancel()
        debounceTask = nil
        activeItemID = nil
        previewImage = nil
        previewError = nil
        isLoading = false
    }

    // MARK: - Private load pipeline

    private func fetch(item: DroidFileItem, deviceSerial: String) async {
        let key = cacheKey(serial: deviceSerial, item: item)
        let cachedURL = cacheDir.appendingPathComponent(key + ".jpg")

        // 命中磁盘缓存 → 直接返回
        if let img = loadDisk(cachedURL) {
            previewImage = img
            isLoading = false
            return
        }

        // 未命中 → 从设备拉取
        do {
            let img = try await pullThumbnail(item: item, deviceSerial: deviceSerial, saveTo: cachedURL)
            guard !Task.isCancelled else { return }
            previewImage = img
            isLoading = false
            // 后台修剪缓存
            Task { await Self.trimCache(dir: cacheDir, maxBytes: maxCacheBytes) }
        } catch {
            guard !Task.isCancelled else { return }
            previewError = error.localizedDescription
            isLoading = false
        }
    }

    private func loadDisk(_ url: URL) -> NSImage? {
        guard FileManager.default.fileExists(atPath: url.path),
              let img = NSImage(contentsOf: url) else { return nil }
        // 更新访问时间用于 LRU
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return img
    }

    private func pullThumbnail(
        item: DroidFileItem,
        deviceSerial: String,
        saveTo cacheURL: URL
    ) async throws -> NSImage {
        let br = bridge
        let maxPx = thumbnailMaxPx

        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {

                // 1. 尝试 Android MediaStore 缩略图
                if let thumbPath = br.findAndroidThumbnailPath(
                    deviceSerial: deviceSerial, remotePath: item.fullPath
                ) {
                    let tmp = Self.tempURL(ext: "jpg")
                    defer { try? FileManager.default.removeItem(at: tmp) }
                    if (try? br.pullFileToURL(deviceSerial: deviceSerial, remotePath: thumbPath, localURL: tmp)) != nil,
                       let img = NSImage(contentsOf: tmp) {
                        let thumb = Self.resize(img, maxPx: maxPx)
                        Self.writeJPEG(thumb, to: cacheURL)
                        cont.resume(returning: thumb)
                        return
                    }
                }

                // 2. 拉原图 → 本地生成缩略图
                let ext = (item.name as NSString).pathExtension
                let tmp = Self.tempURL(ext: ext.isEmpty ? "bin" : ext)
                defer { try? FileManager.default.removeItem(at: tmp) }
                do {
                    try br.pullFileToURL(deviceSerial: deviceSerial, remotePath: item.fullPath, localURL: tmp)
                    guard let original = NSImage(contentsOf: tmp) else {
                        throw DroidBridgeError.commandFailed("Cannot decode image")
                    }
                    let thumb = Self.resize(original, maxPx: maxPx)
                    Self.writeJPEG(thumb, to: cacheURL)
                    cont.resume(returning: thumb)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Cache helpers

    private func cacheKey(serial: String, item: DroidFileItem) -> String {
        // FNV-1a 64-bit，足够作 cache key
        let raw = "\(serial)|\(item.fullPath)|\(item.sizeDescription)"
        var h: UInt64 = 14695981039346656037
        for b in raw.utf8 { h ^= UInt64(b); h = h &* 1099511628211 }
        return String(format: "%016llx", h)
    }

    private static func trimCache(dir: URL, maxBytes: Int) async {
        DispatchQueue.global(qos: .background).async {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
            ) else { return }

            var infos: [(URL, Int, Date)] = files.compactMap { url in
                guard let r = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                      let sz = r.fileSize, let dt = r.contentModificationDate
                else { return nil }
                return (url, sz, dt)
            }

            let total = infos.reduce(0) { $0 + $1.1 }
            guard total > maxBytes else { return }

            infos.sort { $0.2 < $1.2 }   // 最旧的先删
            var remaining = total
            for (url, sz, _) in infos {
                guard remaining > maxBytes else { break }
                try? FileManager.default.removeItem(at: url)
                remaining -= sz
            }
        }
    }

    // MARK: - Image utilities

    private static func tempURL(ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + ext)
    }

    private static func resize(_ image: NSImage, maxPx: CGFloat) -> NSImage {
        let sz = image.size
        guard sz.width > 0, sz.height > 0 else { return image }
        let scale = min(maxPx / sz.width, maxPx / sz.height, 1.0)
        guard scale < 1.0 else { return image }
        let newSz = NSSize(width: (sz.width * scale).rounded(),
                           height: (sz.height * scale).rounded())
        let out = NSImage(size: newSz)
        out.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSz),
                   from: NSRect(origin: .zero, size: sz),
                   operation: .copy, fraction: 1.0)
        out.unlockFocus()
        return out
    }

    private static func writeJPEG(_ image: NSImage, to url: URL) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else { return }
        try? data.write(to: url)
    }
}
