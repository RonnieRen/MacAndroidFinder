import AppKit
import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - QRPairingView
//
// GroupBox section inside WirelessConnectionSheet implementing the
// "pair device with QR code" flow. All state lives in QRPairingController.

struct QRPairingView: View {
    @ObservedObject var controller: QRPairingController

    var body: some View {
        GroupBox(L10n.qrPairTitle()) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.qrPairHint())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                content
            }
            .padding(.top, 2)
        }
        .onDisappear {
            controller.stopPollingOnDisappear()
        }
    }

    // MARK: - Phase content

    @ViewBuilder
    private var content: some View {
        switch controller.phase {
        case .idle:
            Button(L10n.qrPairStart()) { controller.start() }

        case .waitingForScan, .pairing, .connecting:
            HStack(alignment: .top, spacing: 12) {
                qrImageView
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(phaseLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button(L10n.cancel()) { controller.cancel() }
                }
            }

        case .succeeded(let endpoint):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(L10n.qrPairSucceeded(endpoint))
                    .font(.caption)
                Spacer()
                Button(L10n.qrPairStart()) { controller.start() }
            }

        case .failed(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .lineLimit(2)
                Spacer()
                Button(L10n.retry()) { controller.start() }
            }
        }
    }

    private var phaseLabel: String {
        switch controller.phase {
        case .pairing: return L10n.qrPairing()
        case .connecting: return L10n.qrConnecting()
        default: return L10n.qrWaitingForScan()
        }
    }

    @ViewBuilder
    private var qrImageView: some View {
        if let payload = controller.qrPayload, let image = Self.qrImage(from: payload) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: 130, height: 130)
                .background(Color.white)
                .cornerRadius(6)
        }
    }

    // MARK: - QR rendering

    static func qrImage(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
