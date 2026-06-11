import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - DroidFinderViewModel (Drag-out / export to Finder)
//
// Split out of `DroidFinderViewModel.swift` to respect the 500-line ceiling.

extension DroidFinderViewModel {
    // MARK: - Share

    /// Pull the file to a temp location, then present the system share picker
    /// anchored to `anchor`.
    func share(_ item: DroidFileItem, from anchor: NSView) {
        guard let selectedDevice else { return }
        let serial = selectedDevice.id
        let br = bridgeService
        statusMessage = L10n.preparingShare(item.name)

        Task.detached(priority: .userInitiated) { [weak self] in
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("DroidFinder", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let dest = tempDir.appendingPathComponent(item.name)
            try? FileManager.default.removeItem(at: dest)

            do {
                try br.pullFileToURL(deviceSerial: serial, remotePath: item.fullPath, localURL: dest)
                await MainActor.run { [weak self] in
                    self?.statusMessage = L10n.ready()
                    let picker = NSSharingServicePicker(items: [dest])
                    picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = error.localizedDescription
                    self?.statusMessage = L10n.shareFailed()
                }
            }
        }
    }

    // MARK: - Drag-out

    /// Build NSItemProviders for a batch of items (multi-select drag).
    /// Returns one provider per item; the caller is responsible for handing
    /// them all to a single NSDraggingSession so Finder receives them together.
    func makeDragItemProviders(for items: [DroidFileItem]) -> [NSItemProvider] {
        items.compactMap { makeDragItemProvider(for: $0) }
    }

    /// Build NSFilePromiseProviders for a batch of items. Promise providers
    /// are the AppKit-native way to drag remote/on-demand files into Finder:
    /// Finder accepts the promise, asks our delegate for the file name, and
    /// then calls back to materialise the file at its drop location. This is
    /// what our `MultiItemDragOverlay` actually feeds into NSDraggingSession.
    func makeFilePromiseProviders(for items: [DroidFileItem]) -> [NSFilePromiseProvider] {
        guard let serial = selectedDevice?.id else { return [] }
        let br = bridgeService
        return items.map { item in
            let fileType = UTType(filenameExtension: (item.name as NSString).pathExtension)?.identifier
                ?? UTType.data.identifier
            let delegate = FileExportPromiseDelegate(item: item, deviceSerial: serial, bridge: br)
            let provider = NSFilePromiseProvider(fileType: fileType, delegate: delegate)
            // The promise provider only holds a weak reference to its
            // delegate, so we keep the delegate alive for the lifetime of the
            // provider via associated objects.
            objc_setAssociatedObject(
                provider,
                &FileExportPromiseDelegate.associationKey,
                delegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            return provider
        }
    }

    /// Build an NSItemProvider that, when dropped into Finder, pulls the remote file there.
    func makeDragItemProvider(for item: DroidFileItem) -> NSItemProvider? {
        guard let serial = selectedDevice?.id else { return nil }
        let fileType = UTType(filenameExtension: (item.name as NSString).pathExtension)?.identifier
            ?? UTType.item.identifier
        let br = bridgeService
        let remotePath = item.fullPath
        let fileName = item.name

        let itemProvider = NSItemProvider()
        itemProvider.suggestedName = fileName
        itemProvider.registerFileRepresentation(
            forTypeIdentifier: fileType,
            fileOptions: [],
            visibility: .all
        ) { completion in
            let progress = Progress(totalUnitCount: 1)
            DispatchQueue.global(qos: .userInitiated).async {
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("DroidFinder", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let dest = tempDir.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: dest)
                do {
                    try br.pullFileToURL(deviceSerial: serial, remotePath: remotePath, localURL: dest)
                    progress.completedUnitCount = 1
                    completion(dest, false, nil)
                } catch {
                    completion(nil, false, error)
                }
            }
            return progress
        }
        return itemProvider
    }
}
