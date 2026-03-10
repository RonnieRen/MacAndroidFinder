import Foundation

enum AppLanguage {
    case english
    case chineseSimplified
}

enum L10n {
    static var currentLanguage: AppLanguage {
        let code = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if code.hasPrefix("zh") {
            return .chineseSimplified
        }
        return .english
    }

    static func text(_ english: String, _ chineseSimplified: String) -> String {
        switch currentLanguage {
        case .english:
            return english
        case .chineseSimplified:
            return chineseSimplified
        }
    }

    static func ready() -> String { text("Ready", "准备就绪") }
    static func adbNotFound() -> String { text("adb not found. Please install Android Platform Tools first.", "未找到 adb。请先安装 Android Platform Tools。") }
    static func parseDirectoryFailed() -> String { text("Failed to parse Android directory listing.", "解析 Android 文件列表失败。") }
    static func downloadFileFailed() -> String { text("File download failed.", "文件下载失败。") }
    static func uploadFileFailed() -> String { text("File upload failed.", "文件上传失败。") }
    static func adbExecuteFailed() -> String { text("adb command failed.", "adb 执行失败。") }
    static func waiting() -> String { text("Pending", "等待中") }
    static func uploading() -> String { text("Uploading", "上传中") }
    static func completed() -> String { text("Completed", "已完成") }
    static func failed() -> String { text("Failed", "失败") }
    static func uploadDone() -> String { text("Upload completed", "上传完成") }
    static func uploaded(file: String) -> String { text("Uploaded: \(file)", "已上传：\(file)") }
    static func uploadFailed(file: String) -> String { text("Upload failed: \(file)", "上传失败：\(file)") }
    static func loadedItems(_ count: Int) -> String { text("Loaded \(count) item(s)", "已加载 \(count) 项") }
    static func directoryReadFailed() -> String { text("Failed to read directory", "目录读取失败") }
    static func chooseDownloadDirectory() -> String { text("Choose download folder", "选择下载目录") }
    static func downloadedFile(_ name: String) -> String { text("Downloaded: \(name)", "已下载：\(name)") }
    static func downloadedDirectory(_ name: String) -> String { text("Downloaded folder: \(name)", "已下载目录：\(name)") }
    static func downloadFailed() -> String { text("Download failed", "下载失败") }
    static func downloadDirectoryFailed() -> String { text("Folder download failed", "目录下载失败") }
    static func uploadTo(_ remoteDirectory: String) -> String { text("Upload to \(remoteDirectory)", "上传到 \(remoteDirectory)") }
    static func noDevice(_ bridgeInfo: String) -> String { text("No available device (\(bridgeInfo)). Please connect your phone and enable USB debugging.", "没有可用设备（\(bridgeInfo)）。请连接手机并开启 USB 调试。") }
    static func unableToReadDevice() -> String { text("Unable to read devices.", "无法读取设备。") }
    static func adbPath(_ path: String?) -> String {
        text("adb: \(path ?? "not found")", "adb: \(path ?? "未找到")")
    }
    static func refreshDevices() -> String { text("Refresh Devices", "刷新设备") }
    static func parentDirectory() -> String { text("Up", "上一级") }
    static func uploadFiles() -> String { text("Upload", "上传文件") }
    static func uploadHere() -> String { text("Upload Here", "上传到当前目录") }
    static func openDirectory() -> String { text("Open Folder", "进入目录") }
    static func downloadFile() -> String { text("Download File", "下载文件") }
    static func downloadDirectory() -> String { text("Download Folder", "下载目录") }
    static func deviceLabel() -> String { text("Device", "设备") }
    static func directoryTree() -> String { text("Directory Tree", "目录树") }
    static func folder() -> String { text("Folder", "文件夹") }
    static func file() -> String { text("File", "文件") }
    static func emptyDirectory() -> String { text("Current directory is empty", "当前目录为空") }
    static func dropToUpload(_ path: String) -> String { text("Drop to upload to: \(path)", "松开即可上传到：\(path)") }
    static func uploadQueue() -> String { text("Upload Queue", "上传队列") }
    static func clearFinished() -> String { text("Clear Finished", "清理已完成") }
    static func close() -> String { text("Close", "关闭") }
    static func loadingErrorTitle() -> String { text("Error", "错误") }
    static func ok() -> String { text("OK", "确定") }
    static func unknownError() -> String { text("Unknown error", "未知错误") }
    static func statusUploading() -> String { text("Uploading…", "上传中…") }
    static func phoneRoot() -> String { text("Phone", "手机") }
    static func cameraRoot() -> String { text("Camera", "相机") }
    static func wirelessConnect() -> String { text("Wireless Connect", "无线连接") }
    static func wirelessConnectTitle() -> String { text("Connect Android Over Wi-Fi", "通过 Wi-Fi 连接 Android") }
    static func usbQuickConnect() -> String { text("USB Quick Connect", "USB 快速连接") }
    static func usbQuickConnectHint() -> String { text("Connect with USB once and then switch to Wi-Fi automatically.", "先通过 USB 连接一次，再自动切换到 Wi-Fi。") }
    static func connectUsingUSB() -> String { text("Connect via USB Device", "使用 USB 设备连接") }
    static func noUSBDeviceSelected() -> String { text("Select a USB-connected device first.", "请先选择一个 USB 连接的设备。") }
    static func nearbyDevices() -> String { text("Nearby Devices", "附近设备") }
    static func discover() -> String { text("Discover", "发现设备") }
    static func noNearbyDevices() -> String { text("No nearby wireless devices found.", "未发现附近无线设备。") }
    static func pairWithCode() -> String { text("Pair with Code", "使用配对码") }
    static func pairEndpoint() -> String { text("Pair Endpoint (IP:PORT)", "配对端点（IP:端口）") }
    static func pairCode() -> String { text("Pair Code", "配对码") }
    static func connectEndpoint() -> String { text("Connect Endpoint (IP:PORT)", "连接端点（IP:端口）") }
    static func pairAndConnect() -> String { text("Pair and Connect", "配对并连接") }
    static func manualConnect() -> String { text("Manual Connect", "手动连接") }
    static func endpoint() -> String { text("Endpoint (IP:PORT)", "端点（IP:端口）") }
    static func connect() -> String { text("Connect", "连接") }
    static func disconnectAll() -> String { text("Disconnect All", "断开全部连接") }
    static func disconnect() -> String { text("Disconnect", "断开连接") }
    static func discoveringWireless() -> String { text("Discovering wireless devices…", "正在发现无线设备…") }
    static func discoveredWirelessCount(_ count: Int) -> String { text("Found \(count) wireless device(s).", "发现 \(count) 个无线设备。") }
    static func connectedEndpoint(_ endpoint: String) -> String { text("Connected: \(endpoint)", "已连接：\(endpoint)") }
    static func pairedEndpoint(_ endpoint: String) -> String { text("Paired: \(endpoint)", "已配对：\(endpoint)") }
    static func disconnectedEndpoint(_ endpoint: String) -> String { text("Disconnected: \(endpoint)", "已断开：\(endpoint)") }
    static func disconnectedAll() -> String { text("Disconnected all wireless devices.", "已断开所有无线设备连接。") }
    static func invalidEndpoint() -> String { text("Please enter endpoint as IP:PORT.", "请输入 IP:端口 格式的端点。") }
    static func invalidPairInput() -> String { text("Please enter pair endpoint, pair code, and connect endpoint.", "请输入配对端点、配对码和连接端点。") }
    static func wifiConnectFromUSBFailedIP() -> String { text("Failed to get phone Wi-Fi IP from USB device.", "无法从 USB 设备获取手机 Wi-Fi IP。") }
    static func deleteItem() -> String { text("Delete", "删除") }
    static func deleteFile() -> String { text("Delete File", "删除文件") }
    static func deleteFolder() -> String { text("Delete Folder", "删除文件夹") }
    static func deleteConfirmTitle() -> String { text("Confirm Delete", "确认删除") }
    static func deleteConfirmMessage(_ name: String) -> String { text("Delete \"\(name)\" permanently?", "确定永久删除 “\(name)” 吗？") }
    static func deleteConfirmMessageFolder(_ name: String) -> String { text("Delete folder \"\(name)\" and all its contents permanently?", "确定永久删除文件夹 “\(name)” 及其全部内容吗？") }
    static func cancel() -> String { text("Cancel", "取消") }
    static func deletedFile(_ name: String) -> String { text("Deleted file: \(name)", "已删除文件：\(name)") }
    static func deletedFolder(_ name: String) -> String { text("Deleted folder: \(name)", "已删除文件夹：\(name)") }
    static func deleteFailed() -> String { text("Delete failed", "删除失败") }
    static func deleteRootNotAllowed() -> String { text("Deleting root path is not allowed.", "不允许删除根目录。") }
    static func editMode() -> String { text("Edit", "编辑") }
    static func done() -> String { text("Done", "完成") }
    static func deleteSelected() -> String { text("Delete Selected", "删除已选") }
    static func selectedCount(_ count: Int) -> String { text("\(count) selected", "已选 \(count) 项") }
    static func deleteSelectedConfirmMessage(_ count: Int) -> String {
        text("Delete \(count) selected item(s) permanently?", "确定永久删除已选的 \(count) 项吗？")
    }
    static func deletedItemsCount(_ count: Int) -> String { text("Deleted \(count) item(s)", "已删除 \(count) 项") }
}

struct DroidDevice: Identifiable, Hashable {
    let id: String
    let model: String
    let transportState: String

    var displayName: String {
        model.isEmpty ? id : "\(model) (\(id))"
    }
}

struct DroidFileItem: Identifiable, Hashable {
    enum ItemType {
        case file
        case directory
        case symlink
        case unknown
    }

    let id: String
    let name: String
    let fullPath: String
    let type: ItemType
    let sizeDescription: String

    var isDirectory: Bool {
        type == .directory
    }
}

struct WirelessService: Identifiable, Hashable {
    let name: String
    let type: String
    let endpoint: String

    var id: String { "\(name)|\(type)|\(endpoint)" }
}

enum DroidBridgeError: LocalizedError {
    case adbNotFound
    case commandFailed(String)
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return L10n.adbNotFound()
        case .commandFailed(let message):
            return message
        case .parseFailed:
            return L10n.parseDirectoryFailed()
        }
    }
}

final class DroidADBService {
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

    func listWirelessServices() throws -> [WirelessService] {
        let output = try runBridge(args: ["mdns", "services"])
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var services: [WirelessService] = []
        for line in lines {
            guard let parsed = parseWirelessServiceLine(line) else { continue }
            services.append(parsed)
        }

        return services.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func pair(endpoint: String, code: String) throws {
        let result = try runBridgeWithStatus(args: ["pair", endpoint, code])
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
        let combined = "\(result.stdout)\n\(result.stderr)".lowercased()
        if combined.contains("failed") || combined.contains("error") {
            throw DroidBridgeError.commandFailed(result.stdout + result.stderr)
        }
    }

    func connect(endpoint: String) throws {
        let result = try runBridgeWithStatus(args: ["connect", endpoint])
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
        let combined = "\(result.stdout)\n\(result.stderr)".lowercased()
        if combined.contains("failed") || combined.contains("cannot") {
            throw DroidBridgeError.commandFailed(result.stdout + result.stderr)
        }
    }

    func disconnect(endpoint: String?) throws {
        if let endpoint, !endpoint.isEmpty {
            _ = try runBridge(args: ["disconnect", endpoint])
            return
        }
        _ = try runBridge(args: ["disconnect"])
    }

    func quickConnectFromUSB(deviceSerial: String, tcpPort: Int = 5555) throws -> String {
        _ = try runBridge(args: ["-s", deviceSerial, "tcpip", "\(tcpPort)"])
        guard let phoneIP = try resolvePhoneIP(deviceSerial: deviceSerial) else {
            throw DroidBridgeError.commandFailed(L10n.wifiConnectFromUSBFailedIP())
        }

        let endpoint = "\(phoneIP):\(tcpPort)"
        try connect(endpoint: endpoint)
        return endpoint
    }

    func listDirectory(deviceSerial: String, path: String) throws -> [DroidFileItem] {
        let cleanPath = path.isEmpty ? "/" : path
        do {
            let output = try runBridge(args: ["-s", deviceSerial, "shell", "ls", "-l", "-p", cleanPath])
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

        let fallbackOutput = try runBridge(args: ["-s", deviceSerial, "shell", "ls", "-1", "-a", "-p", "-F", cleanPath])
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
        return DroidFileItem(
            id: fullPath,
            name: normalizedName,
            fullPath: fullPath,
            type: itemType,
            sizeDescription: size
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
            sizeDescription: "--"
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
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func pullFile(deviceSerial: String, remotePath: String, localDirectory: URL) throws {
        let result = try runBridgeWithStatus(args: ["-s", deviceSerial, "pull", remotePath, localDirectory.path])
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? L10n.downloadFileFailed() : result.stderr)
        }
    }

    func deletePath(deviceSerial: String, remotePath: String) throws {
        let cleanPath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty, cleanPath != "/" else {
            throw DroidBridgeError.commandFailed(L10n.deleteRootNotAllowed())
        }

        let result = try runBridgeWithStatus(args: ["-s", deviceSerial, "shell", "rm", "-rf", "--", cleanPath])
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? L10n.deleteFailed() : result.stderr)
        }
    }

    func pushFile(deviceSerial: String, localFile: URL, remoteDirectory: String) throws {
        let result = try runBridgeWithStatus(args: ["-s", deviceSerial, "push", localFile.path, remoteDirectory])
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? L10n.uploadFileFailed() : result.stderr)
        }

        // Ask Android media indexers to scan the new file so Gallery-like apps can see it quickly.
        let remoteFilePath = joinedRemotePath(directory: remoteDirectory, fileName: localFile.lastPathComponent)
        refreshMediaIndex(deviceSerial: deviceSerial, remoteFilePath: remoteFilePath)
    }

    private func runBridge(args: [String]) throws -> String {
        let result = try runBridgeWithStatus(args: args)
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? L10n.adbExecuteFailed() : result.stderr)
        }
        return result.stdout
    }

    private func runBridgeWithStatus(args: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
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

        try process.run()
        process.waitUntilExit()

        let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        return (process.terminationStatus, stdout, stderr)
    }

    private func runRaw(command: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe

        try process.run()
        process.waitUntilExit()

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
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

    private func joinedRemotePath(directory: String, fileName: String) -> String {
        let normalizedDirectory = directory.hasSuffix("/") ? String(directory.dropLast()) : directory
        return "\(normalizedDirectory)/\(fileName)"
    }

    private func refreshMediaIndex(deviceSerial: String, remoteFilePath: String) {
        let cmdResult = try? runBridgeWithStatus(args: ["-s", deviceSerial, "shell", "cmd", "media", "rescan", remoteFilePath])
        if cmdResult?.status == 0 {
            return
        }

        _ = try? runBridgeWithStatus(args: [
            "-s", deviceSerial, "shell", "am", "broadcast",
            "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
            "-d", "file://\(remoteFilePath)"
        ])
    }

    private func parseWirelessServiceLine(_ line: String) -> WirelessService? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !parts.isEmpty else { return nil }

        let endpoint = parts.first(where: { token in
            token.contains(":")
            && token.contains(".")
            && !token.contains("_")
            && !token.contains("=")
        })

        guard let endpoint else { return nil }

        let name = parts.first ?? endpoint
        let type = parts.first(where: { $0.contains("_adb") || $0.contains("_tcp") }) ?? "_adb._tcp"
        return WirelessService(name: name, type: type, endpoint: endpoint)
    }

    private func resolvePhoneIP(deviceSerial: String) throws -> String? {
        let routeOutput = try runBridge(args: ["-s", deviceSerial, "shell", "ip", "route"])
        if let ip = extractIP(from: routeOutput) {
            return ip
        }

        let addrOutput = try runBridge(args: ["-s", deviceSerial, "shell", "ip", "-f", "inet", "addr", "show", "wlan0"])
        return extractIP(from: addrOutput)
    }

    private func extractIP(from text: String) -> String? {
        let pattern = #"(\d{1,3}\.){3}\d{1,3}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let matchedRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[matchedRange])
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
