import Foundation

// MARK: - QRPairingController
//
// Drives Android 11+ "pair device with QR code" wireless-debugging flow:
//
// 1. Generate a random service name + password and render them as a QR code
//    in the `WIFI:T:ADB;S:<name>;P:<password>;;` format Android expects.
// 2. The phone scans the code and starts advertising an mDNS
//    `_adb-tls-pairing._tcp` service whose instance name equals `<name>`.
// 3. We poll `adb mdns services` until that service appears, then run
//    `adb pair <endpoint> <password>`.
// 4. After pairing, the phone advertises `_adb-tls-connect._tcp`; we find the
//    entry with the same IP and `adb connect` to it.

@MainActor
final class QRPairingController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case waitingForScan
        case pairing
        case connecting
        case succeeded(String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var qrPayload: String?

    /// Called on the main actor after a successful pair + connect.
    var onConnected: ((String) -> Void)?

    private let bridgeService: DroidADBService
    private var pollTask: Task<Void, Never>?

    init(bridgeService: DroidADBService) {
        self.bridgeService = bridgeService
    }

    func start() {
        cancel()

        let serviceName = "droidfinder-" + Self.randomToken(length: 6)
        let password = Self.randomToken(length: 10)
        qrPayload = "WIFI:T:ADB;S:\(serviceName);P:\(password);;"
        phase = .waitingForScan

        pollTask = Task { [weak self] in
            await self?.run(serviceName: serviceName, password: password)
        }
    }

    func cancel() {
        pollTask?.cancel()
        pollTask = nil
        qrPayload = nil
        phase = .idle
    }

    /// Stop polling but keep a terminal phase (success / failure) visible.
    func stopPollingOnDisappear() {
        pollTask?.cancel()
        pollTask = nil
        if phase == .waitingForScan || phase == .pairing || phase == .connecting {
            qrPayload = nil
            phase = .idle
        }
    }

    // MARK: - Flow

    private func run(serviceName: String, password: String) async {
        let bridge = bridgeService

        // 1. Wait (up to 2 min) for the phone to scan and advertise pairing.
        guard let pairingEndpoint = await waitForEndpoint(timeout: 120, pick: { services in
            let pairing = services.filter { $0.type.contains("adb-tls-pairing") }
            if let exact = pairing.first(where: { $0.name == serviceName }) {
                return exact.endpoint
            }
            // Robustness: some adb builds report a different instance name.
            // If exactly one pairing service is visible, it is ours.
            return pairing.count == 1 ? pairing[0].endpoint : nil
        }) else {
            if !Task.isCancelled { phase = .failed(L10n.qrPairTimeout()) }
            return
        }

        // 2. Pair.
        phase = .pairing
        do {
            try await Self.onBackground { try bridge.pair(endpoint: pairingEndpoint, code: password) }
        } catch {
            if !Task.isCancelled { phase = .failed(error.localizedDescription) }
            return
        }

        // 3. Find the connect endpoint advertised by the same IP and connect.
        phase = .connecting
        let pairingHost = pairingEndpoint.split(separator: ":").first.map(String.init) ?? ""
        guard let connectEndpoint = await waitForEndpoint(timeout: 30, pick: { services in
            services.first(where: {
                $0.type.contains("adb-tls-connect") && $0.endpoint.hasPrefix("\(pairingHost):")
            })?.endpoint
        }) else {
            if !Task.isCancelled { phase = .failed(L10n.qrConnectEndpointNotFound()) }
            return
        }

        do {
            try await Self.onBackground { try bridge.connect(endpoint: connectEndpoint) }
            phase = .succeeded(connectEndpoint)
            qrPayload = nil
            onConnected?(connectEndpoint)
        } catch {
            if !Task.isCancelled { phase = .failed(error.localizedDescription) }
        }
    }

    /// Poll `adb mdns services` once per second until `pick` returns an
    /// endpoint, the timeout elapses, or the task is cancelled.
    private func waitForEndpoint(
        timeout: TimeInterval,
        pick: @escaping ([WirelessService]) -> String?
    ) async -> String? {
        let bridge = bridgeService
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline, !Task.isCancelled {
            let services = (try? await Self.onBackground { try bridge.listAllMDNSServices() }) ?? []
            if let endpoint = pick(services) {
                return endpoint
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return nil
    }

    // MARK: - Helpers

    private static func onBackground<T: Sendable>(_ work: @escaping () throws -> T) async throws -> T {
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

    private static func randomToken(length: Int) -> String {
        let alphabet = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }
}
