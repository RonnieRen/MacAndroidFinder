import Foundation

// MARK: - DeviceDetail
//
// Extra per-device facts shown in the toolbar device pill and the sidebar
// storage gauge. Fetched lazily after a device connects.

struct DeviceDetail: Equatable {
    /// 0...100, nil when the device didn't report one.
    var batteryLevel: Int?
    /// Bytes used / total on the shared storage volume (/sdcard).
    var storageUsedBytes: Int64?
    var storageTotalBytes: Int64?

    var storageFreeBytes: Int64? {
        guard let used = storageUsedBytes, let total = storageTotalBytes else { return nil }
        return max(total - used, 0)
    }

    /// 0...1 fill fraction for the storage bar.
    var storageFraction: Double? {
        guard let used = storageUsedBytes, let total = storageTotalBytes, total > 0 else { return nil }
        return Double(used) / Double(total)
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1 {
            return String(format: gb >= 100 ? "%.0f GB" : "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_000_000
        return String(format: "%.0f MB", mb)
    }
}
