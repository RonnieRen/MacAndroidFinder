import AppKit

// MARK: - FileExportPromiseDelegate
//
// Backs `NSFilePromiseProvider` for drag-out exports: when the user drops a
// remote file onto Finder, this delegate is asked for a file name and to
// physically materialise the file at the destination URL.

final class FileExportPromiseDelegate: NSObject, NSFilePromiseProviderDelegate {
    static var associationKey: UInt8 = 0

    private let item: DroidFileItem
    private let deviceSerial: String
    private let bridge: DroidADBService

    init(item: DroidFileItem, deviceSerial: String, bridge: DroidADBService) {
        self.item = item
        self.deviceSerial = deviceSerial
        self.bridge = bridge
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String {
        item.name
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let br = bridge
        let serial = deviceSerial
        let remotePath = item.fullPath
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try br.pullFileToURL(deviceSerial: serial, remotePath: remotePath, localURL: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        .main
    }
}
