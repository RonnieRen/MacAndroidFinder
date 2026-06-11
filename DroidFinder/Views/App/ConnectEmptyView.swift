import SwiftUI

// MARK: - ConnectEmptyView
//
// Empty state shown when no device is connected: USB card + wireless pairing
// card (with inline QR pairing) and a pulsing "searching" hint.

struct ConnectEmptyView: View {
    @ObservedObject var qrController: QRPairingController
    let onOpenAdvanced: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(L10n.connectTitle())
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(DFTheme.ink)

            Text(L10n.connectSub())
                .font(.system(size: 13))
                .foregroundStyle(DFTheme.ink2)
                .padding(.top, 8)
                .padding(.bottom, 28)

            HStack(alignment: .top, spacing: 16) {
                usbCard
                wirelessCard
            }

            searchingHint
                .padding(.top, 26)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DFTheme.winBG)
        .onAppear {
            if qrController.phase == .idle {
                qrController.start()
            }
        }
        .onDisappear {
            qrController.stopPollingOnDisappear()
        }
    }

    // MARK: - Cards

    private var usbCard: some View {
        card {
            cardIcon("cable.connector")
            Text(L10n.usbCardTitle())
                .font(.system(size: 15, weight: .bold))
                .padding(.bottom, 6)
            Text(L10n.usbCardBody())
                .font(.system(size: 12))
                .foregroundStyle(DFTheme.ink2)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var wirelessCard: some View {
        card {
            cardIcon("wifi")
            Text(L10n.wirelessCardTitle())
                .font(.system(size: 15, weight: .bold))
                .padding(.bottom, 6)
            Text(L10n.wirelessCardBody())
                .font(.system(size: 12))
                .foregroundStyle(DFTheme.ink2)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            qrArea
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            HStack {
                Spacer()
                Button(L10n.advancedWireless(), action: onOpenAdvanced)
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var qrArea: some View {
        switch qrController.phase {
        case .waitingForScan, .pairing, .connecting:
            VStack(spacing: 8) {
                QRPayloadImage(payload: qrController.qrPayload)
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(qrStatusText)
                        .font(.system(size: 11))
                        .foregroundStyle(DFTheme.ink3)
                }
            }
        case .succeeded(let endpoint):
            Label(L10n.qrPairSucceeded(endpoint), systemImage: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DFTheme.green)
        case .failed(let message):
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(DFTheme.red)
                    .lineLimit(2)
                Button(L10n.retry()) { qrController.start() }
                    .buttonStyle(DFButtonStyle(height: 28))
            }
        case .idle:
            Button(L10n.qrPairStart()) { qrController.start() }
                .buttonStyle(DFButtonStyle(height: 30))
        }
    }

    private var qrStatusText: String {
        switch qrController.phase {
        case .pairing: return L10n.qrPairing()
        case .connecting: return L10n.qrConnecting()
        default: return L10n.qrWaitingForScan()
        }
    }

    // MARK: - Pieces

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(22)
        .frame(width: 300, alignment: .leading)
        .frame(minHeight: 220, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(DFTheme.line, lineWidth: 1)
        )
    }

    private func cardIcon(_ systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(DFTheme.accentSoft)
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DFTheme.accent)
            }
            .padding(.bottom, 14)
    }

    private var searchingHint: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(DFTheme.accent)
                .frame(width: 7, height: 7)
                .shadow(color: DFTheme.accent.opacity(0.3), radius: 3)
            Text(L10n.searchingDevices())
                .font(.system(size: 12))
                .foregroundStyle(DFTheme.ink3)
        }
    }
}

// MARK: - QRPayloadImage

/// Renders a `WIFI:T:ADB;…` payload as a QR image (shared with QRPairingView).
struct QRPayloadImage: View {
    let payload: String?

    var body: some View {
        if let payload, let image = QRPairingView.qrImage(from: payload) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: 130, height: 130)
                .background(Color.white)
                .cornerRadius(6)
        }
    }
}
