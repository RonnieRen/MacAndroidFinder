import Foundation

// MARK: - DroidADBService
//
// Thin wrapper around the local `adb` command. Discovers the binary, lists
// USB devices, walks remote directories, and pulls/pushes/deletes files on
// behalf of the rest of the app. Wireless ADB (mDNS discovery, pair/connect,
// QR pairing) lives in `DroidADBService+Wireless.swift`.

final class DroidADBService {
    /// Default watchdog for short-lived adb commands (listing, shell, mdns…).
    static let standardTimeout: TimeInterval = 20
    /// Generous ceiling for push/pull of large files.
    static let transferTimeout: TimeInterval = 6 * 3600

    /// Parses dates from `adb shell ls -l` output: "2024-01-15 14:32"
    private static let lsDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private(set) lazy var bridgeToolPath: String? = {
        for path in candidateBridgePaths() where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }()

    func checkBridgeReady() throws {
        guard bridgeToolPath != nil else {
            throw DroidBridgeError.adbNotFound
        }
    }

    // MARK: - Devices

    func listDevices() throws -> [DroidDevice] {
        let output = try runBridge(args: ["devices", "-l"])
        let lines = output
            .components(separatedBy: .newlines)
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return lines.compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { return nil }

            let serial = String(parts[0])
            let state = String(parts[1])

            var model = ""
            if let modelPart = parts.first(where: { $0.hasPrefix("model:") }) {
                model = String(modelPart.replacingOccurrences(of: "model:", with: "")).replacingOccurrences(of: "_", with: " ")
            }

            return DroidDevice(id: serial, model: model, transportState: state)
        }
    }

    // MARK: - Directory listing

    func listDirectory(deviceSerial: String, path: String) throws -> [DroidFileItem] {
        let cleanPath = path.isEmpty ? "/" : path
        do {
            let output = try runBridge(args: ["-s", deviceSerial, "shell", "ls", "-l", "-p", shellQuoted(cleanPath)])
            let lines = output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("total") && !isPermissionDeniedLine($0) }

            let parsed = lines.compactMap { parseDetailedListing(line: $0, parentPath: cleanPath) }
            if !parsed.isEmpty || lines.isEmpty {
                return sortItems(filteredVisibleItems(parsed))
            }
        } catch {
            // Fall through to the simpler listing format.
        }

        let fallbackOutput = try runBridge(args: ["-s", deviceSerial, "shell", "ls", "-1", "-a", "-p", "-F", shellQuoted(cleanPath)])
        let fallbackLines = fallbackOutput
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { $0 != "." && $0 != ".." }
            .filter { !isPermissionDeniedLine($0) }

        let items = fallbackLines.compactMap { parseSimpleListing(entry: $0, parentPath: cleanPath) }
        if items.isEmpty && !fallbackLines.isEmpty {
            throw DroidBridgeError.parseFailed
        }

        return sortItems(filteredVisibleItems(items))
    }

    private func parseDetailedListing(line: String, parentPath: String) -> DroidFileItem? {
        guard let firstChar = line.first else { return nil }
        let components = line.split(separator: " ", omittingEmptySubsequences: true)
        guard components.count >= 8 else { return nil }

        var name = String(components.suffix(from: 7).joined(separator: " "))
        if name.isEmpty { return nil }

        if let symlinkSeparator = name.range(of: " -> ") {
            name = String(name[..<symlinkSeparator.lowerBound])
        }

        let normalizedName = normalizedEntryName(name)
        guard normalizedName != "." && normalizedName != ".." && !normalizedName.isEmpty else {
            return nil
        }

        let itemType: DroidFileItem.ItemType
        switch firstChar {
        case "d": itemType = .directory
        case "-": itemType = .file
        case "l": itemType = .symlink
        default: itemType = .unknown
        }

        let fullPath = buildRemotePath(parentPath: parentPath, name: normalizedName)
        let size = String(components[4])
        // columns[5] = "2024-01-15", columns[6] = "14:32"
        let dateStr = "\(components[5]) \(components[6])"
        let modifiedDate = Self.lsDateFormatter.date(from: dateStr)
        return DroidFileItem(
            id: fullPath,
            name: normalizedName,
            fullPath: fullPath,
            type: itemType,
            sizeDescription: size,
            modifiedDate: modifiedDate
        )
    }

    private func parseSimpleListing(entry: String, parentPath: String) -> DroidFileItem? {
        let raw = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        var itemType: DroidFileItem.ItemType = .file
        if raw.hasSuffix("/") {
            itemType = .directory
        } else if raw.hasSuffix("@") {
            itemType = .symlink
        }

        let normalizedName = normalizedEntryName(raw)
        guard normalizedName != "." && normalizedName != ".." && !normalizedName.isEmpty else {
            return nil
        }

        let fullPath = buildRemotePath(parentPath: parentPath, name: normalizedName)
        return DroidFileItem(
            id: fullPath,
            name: normalizedName,
            fullPath: fullPath,
            type: itemType,
            sizeDescription: "--",
            modifiedDate: nil
        )
    }

    private func normalizedEntryName(_ name: String) -> String {
        var normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = normalized.last, "/@*=|".contains(last) {
            normalized.removeLast()
        }
        return normalized
    }

    private func buildRemotePath(parentPath: String, name: String) -> String {
        if parentPath == "/" {
            return "/\(name)"
        }
        return "\(parentPath)/\(name)"
    }

    private func sortItems(_ items: [DroidFileItem]) -> [DroidFileItem] {
        items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            switch (lhs.modifiedDate, rhs.modifiedDate) {
            case let (l?, r?): return l > r   // newer first
            case (_?, nil):    return true
            case (nil, _?):    return false
            default:           return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    // MARK: - MediaStore queries

    /// Query Android MediaStore to find the system-generated thumbnail for an image.
    /// Returns the remote path of the thumbnail, or nil if not found.
    func findAndroidThumbnailPath(deviceSerial: String, remotePath: String) -> String? {
        let filename = (remotePath as NSString).lastPathComponent

        // Ask MediaStore for the _id of this file. The filename is embedded in
        // an SQL string literal (escape ' as '') and the whole clause is then
        // shell-quoted for the device-side shell.
        let sqlName = filename.replacingOccurrences(of: "'", with: "''")
        guard let output = try? runBridge(args: [
            "-s", deviceSerial, "shell",
            "content", "query",
            "--uri", "content://media/external/images/media",
            "--where", shellQuoted("display_name='\(sqlName)'"),
            "--projection", "_id"
        ]) else { return nil }

        // Parse "Row: 0 _id=12345"
        var mediaID: String?
        for line in output.components(separatedBy: .newlines) {
            if let range = line.range(of: "_id=") {
                let digits = line[range.upperBound...].prefix(while: { $0.isNumber })
                if !digits.isEmpty { mediaID = String(digits); break }
            }
        }
        guard let mediaID else { return nil }

        // Thumbnails live in .thumbnails/ one or two levels above the file
        let parentPath  = (remotePath as NSString).deletingLastPathComponent
        let grandParent = (parentPath  as NSString).deletingLastPathComponent

        for dir in [parentPath, grandParent] {
            let candidate = "\(dir)/.thumbnails/\(mediaID).jpg"
            let check = try? runBridgeWithStatus(args: ["-s", deviceSerial, "shell", "test", "-f", shellQuoted(candidate)])
            if check?.status == 0 { return candidate }
        }
        return nil
    }

    func deletePath(deviceSerial: String, remotePath: String) throws {
        let cleanPath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty, cleanPath != "/" else {
            throw DroidBridgeError.commandFailed(L10n.deleteRootNotAllowed())
        }

        let result = try runBridgeWithStatus(args: ["-s", deviceSerial, "shell", "rm", "-rf", "--", shellQuoted(cleanPath)])
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? L10n.deleteFailed() : result.stderr)
        }
    }

    // MARK: - Device tracking

    /// Spawn a long-lived `adb track-devices` process. The adb server pushes
    /// an updated device list over this connection on every plug/unplug, so
    /// `onChange` fires immediately instead of on a polling interval.
    /// Returns the running process (caller owns its lifetime), or nil if adb
    /// is missing or the spawn failed.
    func startDeviceTracking(onChange: @escaping () -> Void) -> Process? {
        guard let bridgeToolPath else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bridgeToolPath)
        process.arguments = ["track-devices"]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            guard !handle.availableData.isEmpty else {
                handle.readabilityHandler = nil   // EOF — tracker exited
                return
            }
            onChange()
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }
        return process
    }

    // MARK: - Process invocation

    func runBridge(args: [String], timeout: TimeInterval = DroidADBService.standardTimeout) throws -> String {
        let result = try runBridgeWithStatus(args: args, timeout: timeout)
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? L10n.adbExecuteFailed() : result.stderr)
        }
        return result.stdout
    }

    func runBridgeWithStatus(
        args: [String],
        timeout: TimeInterval = DroidADBService.standardTimeout
    ) throws -> (status: Int32, stdout: String, stderr: String) {
        guard let bridgeToolPath else {
            throw DroidBridgeError.adbNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bridgeToolPath)
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        try process.run()

        // Watchdog: a hung adb (dead wireless connection, stuck server) would
        // otherwise block its caller forever.
        let timedOut = LockedFlag()
        let watchdog = DispatchWorkItem {
            timedOut.set()
            process.terminate()
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)

        // Drain both pipes BEFORE waiting on the process. If the child fills
        // a pipe buffer (~64 KB) while we sit in waitUntilExit(), the child
        // blocks on write and we block on wait — a classic deadlock. stderr
        // is drained on a background queue while we read stdout here.
        var stderrData = Data()
        let stderrDrained = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            stderrData = stderrHandle.readDataToEndOfFile()
            stderrDrained.signal()
        }

        let stdoutData = stdoutHandle.readDataToEndOfFile()
        stderrDrained.wait()
        process.waitUntilExit()
        watchdog.cancel()

        if timedOut.isSet {
            throw DroidBridgeError.timedOut
        }

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (process.terminationStatus, stdout, stderr)
    }

    private func runRaw(command: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe

        try process.run()
        // Read before waiting — same deadlock avoidance as runBridgeWithStatus.
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Helpers

    /// Quote a string for the device-side shell. `adb shell` re-joins its
    /// arguments with spaces and the remote shell re-parses the line, so any
    /// path containing spaces or shell metacharacters must be single-quoted.
    func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func candidateBridgePaths() -> [String] {
        var candidates: [String] = []
        let env = ProcessInfo.processInfo.environment

        if let fromWhich = try? runRaw(command: "/usr/bin/which", args: ["adb"])
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !fromWhich.isEmpty {
            candidates.append(fromWhich)
        }

        if let androidHome = env["ANDROID_HOME"], !androidHome.isEmpty {
            candidates.append((androidHome as NSString).appendingPathComponent("platform-tools/adb"))
        }

        if let sdkRoot = env["ANDROID_SDK_ROOT"], !sdkRoot.isEmpty {
            candidates.append((sdkRoot as NSString).appendingPathComponent("platform-tools/adb"))
        }

        let homePath = NSHomeDirectory()
        candidates.append((homePath as NSString).appendingPathComponent("Library/Android/sdk/platform-tools/adb"))
        candidates.append("/opt/homebrew/bin/adb")
        candidates.append("/usr/local/bin/adb")
        candidates.append("/usr/bin/adb")

        var deduped: [String] = []
        for path in candidates where !path.isEmpty {
            if !deduped.contains(path) {
                deduped.append(path)
            }
        }
        return deduped
    }

    private func filteredVisibleItems(_ items: [DroidFileItem]) -> [DroidFileItem] {
        items.filter { !isRestrictedPath($0.fullPath) }
    }

    private func isPermissionDeniedLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("permission denied")
            || lower.contains("operation not permitted")
            || (lower.hasPrefix("ls:") && lower.contains("denied"))
    }

    private func isRestrictedPath(_ path: String) -> Bool {
        let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let blockedPrefixes = [
            "/sdcard/android/data",
            "/sdcard/android/obb",
            "/storage/emulated/0/android/data",
            "/storage/emulated/0/android/obb"
        ]
        return blockedPrefixes.contains { normalized == $0 || normalized.hasPrefix($0 + "/") }
    }
}

extension DroidADBService: @unchecked Sendable {}

// MARK: - LockedFlag

/// Minimal thread-safe boolean used by the process watchdog.
private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
