import Foundation

// MARK: - DroidADBService (Device info)
//
// Battery level and shared-storage usage for the toolbar device pill and
// sidebar storage gauge. Both are best-effort: parse failures return nil
// fields rather than throwing.

extension DroidADBService {
    func fetchDeviceDetail(deviceSerial: String) -> DeviceDetail {
        var detail = DeviceDetail()
        detail.batteryLevel = batteryLevel(deviceSerial: deviceSerial)
        if let (used, total) = storageUsage(deviceSerial: deviceSerial) {
            detail.storageUsedBytes = used
            detail.storageTotalBytes = total
        }
        return detail
    }

    /// `dumpsys battery` → "  level: 82"
    private func batteryLevel(deviceSerial: String) -> Int? {
        guard let output = try? runBridge(args: ["-s", deviceSerial, "shell", "dumpsys", "battery"]) else {
            return nil
        }
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("level:") else { continue }
            let value = trimmed.dropFirst("level:".count).trimmingCharacters(in: .whitespaces)
            if let level = Int(value), (0...100).contains(level) {
                return level
            }
        }
        return nil
    }

    /// `df /sdcard` → "/dev/fuse  243617788  155003008  88598396  64% /storage/emulated"
    /// Sizes are 1K blocks unless a `df -k`-style header says otherwise.
    private func storageUsage(deviceSerial: String) -> (used: Int64, total: Int64)? {
        guard let output = try? runBridge(args: ["-s", deviceSerial, "shell", "df", "/sdcard"]) else {
            return nil
        }
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // Skip the header row; take the first data row with ≥4 columns.
        for line in lines.dropFirst() {
            let cols = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard cols.count >= 4,
                  let totalKB = Int64(cols[1]),
                  let usedKB = Int64(cols[2]),
                  totalKB > 0 else { continue }
            return (usedKB * 1024, totalKB * 1024)
        }
        return nil
    }
}
