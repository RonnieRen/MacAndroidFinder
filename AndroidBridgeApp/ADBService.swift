import Foundation

struct AndroidDevice: Identifiable, Hashable {
    let id: String
    let model: String
    let transportState: String

    var displayName: String {
        model.isEmpty ? id : "\(model) (\(id))"
    }
}

struct AndroidFileItem: Identifiable, Hashable {
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

enum ADBError: LocalizedError {
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

final class ADBService {
    private(set) lazy var adbPath: String? = {
        for path in candidateADBPaths() where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }()

    func checkADBReady() throws {
        guard adbPath != nil else {
            throw ADBError.adbNotFound
        }
    }

    func listDevices() throws -> [AndroidDevice] {
        let output = try runADB(args: ["devices", "-l"])
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

            return AndroidDevice(id: serial, model: model, transportState: state)
        }
    }

    func listDirectory(deviceSerial: String, path: String) throws -> [AndroidFileItem] {
        let cleanPath = path.isEmpty ? "/" : path
        let output = try runADB(args: ["-s", deviceSerial, "shell", "ls", "-l", "-p", cleanPath])
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("total") }

        var items: [AndroidFileItem] = []

        for line in lines {
            guard let firstChar = line.first else { continue }
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 8 else { continue }

            let name = String(components.suffix(from: 7).joined(separator: " "))
            if name.isEmpty { continue }

            let itemType: AndroidFileItem.ItemType
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

            items.append(AndroidFileItem(
                id: fullPath,
                name: normalizedName,
                fullPath: fullPath,
                type: itemType,
                sizeDescription: size
            ))
        }

        if items.isEmpty && !lines.isEmpty {
            throw ADBError.parseFailed
        }

        return items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func pullFile(deviceSerial: String, remotePath: String, localDirectory: URL) throws {
        let result = try runADBWithStatus(args: ["-s", deviceSerial, "pull", remotePath, localDirectory.path])
        guard result.status == 0 else {
            throw ADBError.commandFailed(result.stderr.isEmpty ? "文件下载失败。" : result.stderr)
        }
    }

    func pushFile(deviceSerial: String, localFile: URL, remoteDirectory: String) throws {
        let result = try runADBWithStatus(args: ["-s", deviceSerial, "push", localFile.path, remoteDirectory])
        guard result.status == 0 else {
            throw ADBError.commandFailed(result.stderr.isEmpty ? "文件上传失败。" : result.stderr)
        }
    }

    private func runADB(args: [String]) throws -> String {
        let result = try runADBWithStatus(args: args)
        guard result.status == 0 else {
            throw ADBError.commandFailed(result.stderr.isEmpty ? "adb 执行失败。" : result.stderr)
        }
        return result.stdout
    }

    private func runADBWithStatus(args: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
        guard let adbPath else {
            throw ADBError.adbNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
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

    private func candidateADBPaths() -> [String] {
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
}

extension ADBService: @unchecked Sendable {}
