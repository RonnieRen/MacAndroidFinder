import Foundation

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

enum DroidBridgeError: LocalizedError {
    case adbNotFound
    case commandFailed(String)
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return "未找到 adb。请先安装 Android Platform Tools。"
        case .commandFailed(let message):
            return message
        case .parseFailed:
            return "解析 Android 文件列表失败。"
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

    func listDirectory(deviceSerial: String, path: String) throws -> [DroidFileItem] {
        let cleanPath = path.isEmpty ? "/" : path
        let output = try runBridge(args: ["-s", deviceSerial, "shell", "ls", "-l", "-p", cleanPath])
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("total") }

        var items: [DroidFileItem] = []

        for line in lines {
            guard let firstChar = line.first else { continue }
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 8 else { continue }

            let name = String(components.suffix(from: 7).joined(separator: " "))
            if name.isEmpty { continue }

            let itemType: DroidFileItem.ItemType
            switch firstChar {
            case "d": itemType = .directory
            case "-": itemType = .file
            case "l": itemType = .symlink
            default: itemType = .unknown
            }

            let normalizedName = name
                .replacingOccurrences(of: "*", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let fullPath: String
            if cleanPath == "/" {
                fullPath = "/\(normalizedName)"
            } else {
                fullPath = "\(cleanPath)/\(normalizedName)"
            }

            let size = String(components[4])

            items.append(DroidFileItem(
                id: fullPath,
                name: normalizedName,
                fullPath: fullPath,
                type: itemType,
                sizeDescription: size
            ))
        }

        if items.isEmpty && !lines.isEmpty {
            throw DroidBridgeError.parseFailed
        }

        return items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func pullFile(deviceSerial: String, remotePath: String, localDirectory: URL) throws {
        let result = try runBridgeWithStatus(args: ["-s", deviceSerial, "pull", remotePath, localDirectory.path])
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? "文件下载失败。" : result.stderr)
        }
    }

    func pushFile(deviceSerial: String, localFile: URL, remoteDirectory: String) throws {
        let result = try runBridgeWithStatus(args: ["-s", deviceSerial, "push", localFile.path, remoteDirectory])
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? "文件上传失败。" : result.stderr)
        }

        // Ask Android media indexers to scan the new file so Gallery-like apps can see it quickly.
        let remoteFilePath = joinedRemotePath(directory: remoteDirectory, fileName: localFile.lastPathComponent)
        refreshMediaIndex(deviceSerial: deviceSerial, remoteFilePath: remoteFilePath)
    }

    private func runBridge(args: [String]) throws -> String {
        let result = try runBridgeWithStatus(args: args)
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(result.stderr.isEmpty ? "adb 执行失败。" : result.stderr)
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
}

extension DroidADBService: @unchecked Sendable {}
