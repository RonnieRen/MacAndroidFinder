import Darwin
import Foundation

// MARK: - DroidADBService (Transfer)
//
// push / pull with real-time progress. adb only renders its "[ 45%] path"
// progress meter when stdout is a terminal, so progress-reporting transfers
// run inside a pseudo-terminal (pty) and the master side is read
// incrementally. Callers that pass no `onPercent` get a plain pipe run.

// MARK: - TransferCancelToken

/// Hand one of these to pull/push to allow cancelling a transfer in flight.
/// `cancel()` is thread-safe and terminates the underlying adb process.
final class TransferCancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func register(_ p: Process) {
        lock.lock()
        process = p
        let alreadyCancelled = cancelled
        lock.unlock()
        if alreadyCancelled { p.terminate() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let p = process
        lock.unlock()
        p?.terminate()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

extension DroidADBService {
    // MARK: - Public API

    /// `onPercent` is invoked on a background thread with values 0...100.
    func pullFile(
        deviceSerial: String,
        remotePath: String,
        localDirectory: URL,
        onPercent: ((Int) -> Void)? = nil,
        cancelToken: TransferCancelToken? = nil
    ) throws {
        let result = try runTransfer(
            args: ["-s", deviceSerial, "pull", remotePath, localDirectory.path],
            onPercent: onPercent,
            cancelToken: cancelToken
        )
        if cancelToken?.isCancelled == true {
            throw DroidBridgeError.cancelled
        }
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(Self.lastLine(of: result.output) ?? L10n.downloadFileFailed())
        }
    }

    /// Pull a remote file to a specific local URL (not a directory).
    func pullFileToURL(
        deviceSerial: String,
        remotePath: String,
        localURL: URL,
        onPercent: ((Int) -> Void)? = nil,
        cancelToken: TransferCancelToken? = nil
    ) throws {
        let result = try runTransfer(
            args: ["-s", deviceSerial, "pull", remotePath, localURL.path],
            onPercent: onPercent,
            cancelToken: cancelToken
        )
        if cancelToken?.isCancelled == true {
            throw DroidBridgeError.cancelled
        }
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(Self.lastLine(of: result.output) ?? L10n.downloadFileFailed())
        }
    }

    func pushFile(
        deviceSerial: String,
        localFile: URL,
        remoteDirectory: String,
        onPercent: ((Int) -> Void)? = nil,
        cancelToken: TransferCancelToken? = nil
    ) throws {
        let result = try runTransfer(
            args: ["-s", deviceSerial, "push", localFile.path, remoteDirectory],
            onPercent: onPercent,
            cancelToken: cancelToken
        )
        if cancelToken?.isCancelled == true {
            throw DroidBridgeError.cancelled
        }
        guard result.status == 0 else {
            throw DroidBridgeError.commandFailed(Self.lastLine(of: result.output) ?? L10n.uploadFileFailed())
        }

        // Ask Android media indexers to scan the new file so Gallery-like apps can see it quickly.
        let remoteFilePath = joinedRemotePath(directory: remoteDirectory, fileName: localFile.lastPathComponent)
        refreshMediaIndex(deviceSerial: deviceSerial, remoteFilePath: remoteFilePath)
    }

    // MARK: - pty runner

    private func runTransfer(
        args: [String],
        onPercent: ((Int) -> Void)?,
        cancelToken: TransferCancelToken? = nil
    ) throws -> (status: Int32, output: String) {
        // No progress requested → no reason to pay the pty cost.
        guard let onPercent else {
            let result = try runBridgeWithStatus(args: args, timeout: Self.transferTimeout)
            return (result.status, "\(result.stdout)\n\(result.stderr)")
        }

        guard let bridgeToolPath else {
            throw DroidBridgeError.adbNotFound
        }

        var masterFD: Int32 = -1
        var slaveFD: Int32 = -1
        guard openpty(&masterFD, &slaveFD, nil, nil, nil) == 0 else {
            // pty unavailable — run without progress rather than failing.
            let result = try runBridgeWithStatus(args: args, timeout: Self.transferTimeout)
            return (result.status, "\(result.stdout)\n\(result.stderr)")
        }

        let masterHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bridgeToolPath)
        process.arguments = args
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        do {
            try process.run()
        } catch {
            try? slaveHandle.close()
            try? masterHandle.close()
            throw error
        }
        cancelToken?.register(process)

        // Close the parent's slave copy so the master read loop sees EOF
        // (EIO on macOS) once adb exits.
        try? slaveHandle.close()

        var outputData = Data()
        var lastReported = -1
        while true {
            guard let chunk = try? masterHandle.read(upToCount: 4096), !chunk.isEmpty else {
                break
            }
            outputData.append(chunk)
            if let text = String(data: chunk, encoding: .utf8) {
                for percent in Self.percents(in: text) where percent != lastReported {
                    lastReported = percent
                    onPercent(percent)
                }
            }
        }

        process.waitUntilExit()
        try? masterHandle.close()

        let output = (String(data: outputData, encoding: .utf8) ?? "")
            .replacingOccurrences(of: "\r", with: "\n")
        return (process.terminationStatus, output)
    }

    // MARK: - Output parsing

    private static let percentRegex = try? NSRegularExpression(pattern: #"\[\s*(\d{1,3})%\]"#)

    /// Extract every "[ 45%]" progress token from a chunk of adb output.
    static func percents(in text: String) -> [Int] {
        guard let regex = percentRegex else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text)
                .flatMap { Int(text[$0]) }
                .flatMap { (0...100).contains($0) ? $0 : nil }
        }
    }

    /// Most informative line of a (possibly progress-polluted) output blob.
    private static func lastLine(of output: String) -> String? {
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty }
    }

    // MARK: - Post-push media scan

    private func joinedRemotePath(directory: String, fileName: String) -> String {
        let normalizedDirectory = directory.hasSuffix("/") ? String(directory.dropLast()) : directory
        return "\(normalizedDirectory)/\(fileName)"
    }

    private func refreshMediaIndex(deviceSerial: String, remoteFilePath: String) {
        let cmdResult = try? runBridgeWithStatus(args: ["-s", deviceSerial, "shell", "cmd", "media", "rescan", shellQuoted(remoteFilePath)])
        if cmdResult?.status == 0 {
            return
        }

        _ = try? runBridgeWithStatus(args: [
            "-s", deviceSerial, "shell", "am", "broadcast",
            "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
            "-d", shellQuoted("file://\(remoteFilePath)")
        ])
    }
}
