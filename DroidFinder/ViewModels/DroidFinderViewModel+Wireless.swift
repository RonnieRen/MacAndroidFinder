import Foundation

// MARK: - DroidFinderViewModel (Wireless)
//
// Wireless ADB UI actions: discovery, USB→Wi-Fi quick switch, pair/connect,
// disconnect. Split out of `DroidFinderViewModel.swift` to respect the
// 500-line ceiling.

extension DroidFinderViewModel {
    /// `announce: false` is for background polling (the Wi-Fi dialog's
    /// continuous scan) — no status-bar chatter, no error alerts.
    func discoverWirelessServices(announce: Bool = true) async {
        if announce {
            isWirelessBusy = true
            statusMessage = L10n.discoveringWireless()
        }
        defer {
            if announce { isWirelessBusy = false }
        }

        do {
            wirelessServices = try bridgeService.listWirelessServices()
            if announce {
                statusMessage = L10n.discoveredWirelessCount(wirelessServices.count)
                errorMessage = nil
            }
        } catch {
            if announce { errorMessage = error.localizedDescription }
        }
    }

    /// Pair with the endpoint+code the phone displays, then automatically
    /// find the `_adb-tls-connect` endpoint on the same host and connect —
    /// the user no longer has to type the second port.
    func pairWithCodeAutoConnect(pairEndpoint: String, code: String) async {
        let pairTarget = pairEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let pairCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pairTarget.contains(":"), !pairCode.isEmpty else {
            errorMessage = L10n.invalidPairInput()
            return
        }

        isWirelessBusy = true
        defer { isWirelessBusy = false }

        let bridge = bridgeService
        do {
            try await Self.background { try bridge.pair(endpoint: pairTarget, code: pairCode) }
            statusMessage = L10n.pairedEndpoint(pairTarget)

            // Find the connect endpoint advertised by the same host (≤15s).
            let host = pairTarget.split(separator: ":").first.map(String.init) ?? ""
            var connectEndpoint: String?
            for _ in 0..<15 {
                let services = (try? await Self.background { try bridge.listAllMDNSServices() }) ?? []
                connectEndpoint = services.first(where: {
                    $0.type.contains("adb-tls-connect") && $0.endpoint.hasPrefix("\(host):")
                })?.endpoint
                if connectEndpoint != nil { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard let connectEndpoint else {
                errorMessage = L10n.connectEndpointNotFound()
                return
            }

            try await Self.background { try bridge.connect(endpoint: connectEndpoint) }
            statusMessage = L10n.connectedEndpoint(connectEndpoint)
            errorMessage = nil
            await refreshDevices(showBusy: false, reloadCurrentDirectory: true)
            await discoverWirelessServices(announce: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func background<T: Sendable>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func quickConnectSelectedDeviceViaWiFi() async {
        guard let selectedDevice, !selectedDevice.id.contains(":") else {
            errorMessage = L10n.noUSBDeviceSelected()
            return
        }

        isWirelessBusy = true
        defer { isWirelessBusy = false }

        do {
            let endpoint = try bridgeService.quickConnectFromUSB(deviceSerial: selectedDevice.id)
            statusMessage = L10n.connectedEndpoint(endpoint)
            errorMessage = nil
            await refreshDevices(showBusy: false, reloadCurrentDirectory: true)
            await discoverWirelessServices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectWireless(endpoint: String) async {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(":") else {
            errorMessage = L10n.invalidEndpoint()
            return
        }

        isWirelessBusy = true
        defer { isWirelessBusy = false }

        do {
            try bridgeService.connect(endpoint: trimmed)
            statusMessage = L10n.connectedEndpoint(trimmed)
            errorMessage = nil
            await refreshDevices(showBusy: false, reloadCurrentDirectory: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pairAndConnect(pairEndpoint: String, pairCode: String, connectEndpoint: String) async {
        let pairTarget = pairEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = pairCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let connectTarget = connectEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard pairTarget.contains(":"), connectTarget.contains(":"), !code.isEmpty else {
            errorMessage = L10n.invalidPairInput()
            return
        }

        isWirelessBusy = true
        defer { isWirelessBusy = false }

        do {
            try bridgeService.pair(endpoint: pairTarget, code: code)
            statusMessage = L10n.pairedEndpoint(pairTarget)
            try bridgeService.connect(endpoint: connectTarget)
            statusMessage = L10n.connectedEndpoint(connectTarget)
            errorMessage = nil
            await refreshDevices(showBusy: false, reloadCurrentDirectory: true)
            await discoverWirelessServices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnectWireless(endpoint: String?) async {
        isWirelessBusy = true
        defer { isWirelessBusy = false }

        do {
            let trimmed = endpoint?.trimmingCharacters(in: .whitespacesAndNewlines)
            try bridgeService.disconnect(endpoint: trimmed)
            if let trimmed, !trimmed.isEmpty {
                statusMessage = L10n.disconnectedEndpoint(trimmed)
            } else {
                statusMessage = L10n.disconnectedAll()
            }
            errorMessage = nil
            await refreshDevices(showBusy: false, reloadCurrentDirectory: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
