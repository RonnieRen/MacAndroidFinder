import Foundation

// MARK: - DroidADBService (Wireless)
//
// Wireless ADB: mDNS service discovery, pair / connect / disconnect, and the
// USB-to-Wi-Fi quick switch. Split out of `DroidADBService.swift` to respect
// the 500-line file ceiling.

extension DroidADBService {
    // MARK: - mDNS discovery

    /// Every mDNS service `adb mdns services` reports, including
    /// `_adb-tls-pairing` entries that only exist while a phone is showing
    /// the "pair with QR code" screen.
    func listAllMDNSServices() throws -> [WirelessService] {
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

    /// Services a user can actually `adb connect` to (pairing-only endpoints
    /// are excluded — connecting to those always fails).
    func listWirelessServices() throws -> [WirelessService] {
        try listAllMDNSServices().filter { !$0.type.contains("adb-tls-pairing") }
    }

    /// Pairing services advertised by phones currently showing the
    /// "pair device with QR code" screen.
    func listPairingServices() throws -> [WirelessService] {
        try listAllMDNSServices().filter { $0.type.contains("adb-tls-pairing") }
    }

    private func parseWirelessServiceLine(_ line: String) -> WirelessService? {
        let parts = line
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)
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

    // MARK: - Pair / connect

    // Success is detected by positively matching adb's known success phrases
    // ("Successfully paired to …" / "connected to …" / "already connected
    // to …"). adb pair/connect often exit 0 on failure, so the exit status
    // alone is not trustworthy — but grepping for "failed"/"error" is worse,
    // since device names can contain those words.

    func pair(endpoint: String, code: String) throws {
        let result = try runBridgeWithStatus(args: ["pair", endpoint, code])
        let combined = "\(result.stdout)\n\(result.stderr)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.status == 0, combined.lowercased().contains("successfully paired") else {
            throw DroidBridgeError.commandFailed(combined.isEmpty ? L10n.adbExecuteFailed() : combined)
        }
    }

    func connect(endpoint: String) throws {
        let result = try runBridgeWithStatus(args: ["connect", endpoint])
        let combined = "\(result.stdout)\n\(result.stderr)".trimmingCharacters(in: .whitespacesAndNewlines)
        // "connected to X" and "already connected to X" are successes;
        // "failed to connect to X" / "cannot connect to X" do not match.
        guard result.status == 0, combined.lowercased().contains("connected to") else {
            throw DroidBridgeError.commandFailed(combined.isEmpty ? L10n.adbExecuteFailed() : combined)
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

    // MARK: - Helpers

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
}
