import SwiftUI

// MARK: - WirelessConnectionSheet
//
// "通过 Wi-Fi 连接" dialog (handoff screen 06): 640px modal with four blocks —
// USB quick-enable (recommended card), nearby-device auto scan, QR pairing,
// and pairing-code entry — plus a help footer.

struct WirelessConnectionSheet: View {
    @ObservedObject var viewModel: DroidFinderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pairEndpoint = ""
    @State private var pairCode = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 12) {
                usbQuickEnableCard
                nearbyCard
                HStack(alignment: .top, spacing: 12) {
                    qrCard
                    codeCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)

            footer
        }
        .frame(width: 640)
        .background(Color.white)
        .task {
            startQRIfIdle()
            // Continuous scan while the dialog is open.
            while !Task.isCancelled {
                await viewModel.discoverWirelessServices(announce: false)
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.wifiDialogTitle())
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DFTheme.ink)
                Text(L10n.wifiDialogSub())
                    .font(.system(size: 12))
                    .foregroundStyle(DFTheme.ink2)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(DFTheme.fieldBG)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(DFTheme.ink2)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var footer: some View {
        HStack {
            Text(L10n.dialogFootHelp())
                .font(.system(size: 12))
                .foregroundStyle(DFTheme.ink3)
            Spacer()
            Button(L10n.connectHelp()) {
                NSWorkspace.shared.open(
                    URL(string: "https://developer.android.com/tools/adb#wireless-android11-command-line")!
                )
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DFTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(DFTheme.previewBG)
        .overlay(alignment: .top) {
            DFTheme.lineSoft.frame(height: 1)
        }
    }

    // MARK: - 1. USB quick enable (recommended)

    private var usbQuickEnableCard: some View {
        let usbDevice = viewModel.devices.first(where: { !$0.id.contains(":") })

        return card(recommended: true) {
            cardHead(
                icon: "cable.connector",
                title: L10n.usbQuickEnableTitle(),
                badge: L10n.recommendedBadge(),
                desc: L10n.usbQuickEnableDesc(),
                recommended: true
            )

            HStack(spacing: 10) {
                Circle()
                    .fill(usbDevice != nil ? DFTheme.green : Color(red: 0xB9 / 255, green: 0xB9 / 255, blue: 0xC2 / 255))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(usbDevice?.displayName ?? L10n.noUSBDeviceRow())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(usbDevice != nil ? DFTheme.ink : DFTheme.ink2)
                    Text(usbDevice != nil ? L10n.usbConnectedReady() : L10n.usbQuickConnectHint())
                        .font(.system(size: 11))
                        .foregroundStyle(DFTheme.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button(L10n.enableWireless()) {
                    Task {
                        // Quick-enable always targets the USB device, even if
                        // a wireless device is currently selected.
                        if let usbDevice { viewModel.selectedDevice = usbDevice }
                        await viewModel.quickConnectSelectedDeviceViaWiFi()
                    }
                }
                .buttonStyle(DFButtonStyle(isPrimary: true, height: 30))
                .disabled(usbDevice == nil || viewModel.isWirelessBusy)
                .opacity(usbDevice == nil ? 0.5 : 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(DFTheme.accentSoft2, lineWidth: 1)
            )
            .padding(.top, 12)
        }
    }

    // MARK: - 2. Nearby devices

    private var nearbyCard: some View {
        card {
            HStack(alignment: .top, spacing: 11) {
                cardIcon("wifi", recommended: false)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.nearbyDevices())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DFTheme.ink)
                    Text(L10n.nearbyDesc())
                        .font(.system(size: 12))
                        .foregroundStyle(DFTheme.ink2)
                }
                Spacer(minLength: 8)
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text(L10n.scanningLabel())
                        .font(.system(size: 11))
                        .foregroundStyle(DFTheme.ink3)
                }
                .padding(.top, 2)
            }

            ForEach(viewModel.wirelessServices) { service in
                nearbyRow(service)
            }
        }
    }

    private func nearbyRow(_ service: WirelessService) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(DFTheme.green)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(service.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DFTheme.ink)
                    .lineLimit(1)
                Text(service.endpoint)
                    .font(.system(size: 11))
                    .foregroundStyle(DFTheme.ink3)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            Button(L10n.connect()) {
                Task { await viewModel.connectWireless(endpoint: service.endpoint) }
            }
            .buttonStyle(DFButtonStyle(height: 30))
            .disabled(viewModel.isWirelessBusy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(DFTheme.line, lineWidth: 1)
        )
        .padding(.top, 12)
    }

    // MARK: - 3. QR pairing

    private var qrCard: some View {
        card {
            cardHead(
                icon: "qrcode",
                title: L10n.qrPairTitle(),
                badge: nil,
                desc: L10n.qrPairHint(),
                recommended: false
            )

            // Separate subview so QR phase changes re-render (the controller
            // is its own ObservableObject, not republished by the view model).
            QRPairingInline(controller: viewModel.qrPairingController)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - 4. Pairing code

    private var codeCard: some View {
        card {
            cardHead(
                icon: "key",
                title: L10n.codePairTitle(),
                badge: nil,
                desc: L10n.codePairDesc(),
                recommended: false
            )

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField(L10n.pairEndpointPlaceholder(), text: $pairEndpoint)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12).monospacedDigit())
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: DFTheme.controlRadius)
                                .strokeBorder(DFTheme.line, lineWidth: 1)
                        )
                    TextField(L10n.pairCodePlaceholder(), text: $pairCode)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12).monospacedDigit())
                        .padding(.horizontal, 11)
                        .frame(width: 92, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: DFTheme.controlRadius)
                                .strokeBorder(DFTheme.line, lineWidth: 1)
                        )
                }
                Button(L10n.pairAndConnect()) {
                    Task { await viewModel.pairWithCodeAutoConnect(pairEndpoint: pairEndpoint, code: pairCode) }
                }
                .buttonStyle(DFButtonStyle(height: 30))
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isWirelessBusy || pairEndpoint.isEmpty || pairCode.isEmpty)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Card scaffolding

    private func card<Content: View>(
        recommended: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(recommended ? DFTheme.accentSoft : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(recommended ? DFTheme.accentSoft2 : DFTheme.line, lineWidth: 1)
        )
    }

    private func cardHead(icon: String, title: String, badge: String?, desc: String, recommended: Bool) -> some View {
        HStack(alignment: .top, spacing: 11) {
            cardIcon(icon, recommended: recommended)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DFTheme.ink)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DFTheme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white))
                            .overlay(Capsule().strokeBorder(DFTheme.accentSoft2, lineWidth: 1))
                    }
                }
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(recommended ? DFTheme.selectedInk2 : DFTheme.ink2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func cardIcon(_ systemName: String, recommended: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(recommended ? Color.white : DFTheme.fieldBG)
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(recommended
                                     ? DFTheme.accent
                                     : Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x5E / 255))
            }
            .shadow(color: recommended ? DFTheme.accent.opacity(0.18) : .clear, radius: 1, y: 1)
    }

    // MARK: - Helpers

    private func startQRIfIdle() {
        if viewModel.qrPairingController.phase == .idle {
            viewModel.qrPairingController.start()
        }
    }
}

// MARK: - QRPairingInline

private struct QRPairingInline: View {
    @ObservedObject var controller: QRPairingController

    var body: some View {
        switch controller.phase {
        case .waitingForScan, .pairing, .connecting:
            HStack(alignment: .bottom, spacing: 10) {
                QRPayloadImage(payload: controller.qrPayload)
                if controller.phase != .waitingForScan {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                        Text(controller.phase == .pairing ? L10n.qrPairing() : L10n.qrConnecting())
                            .font(.system(size: 11))
                            .foregroundStyle(DFTheme.ink3)
                    }
                }
            }
        case .succeeded(let endpoint):
            Label(L10n.qrPairSucceeded(endpoint), systemImage: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DFTheme.green)
        case .failed:
            Button(L10n.retry()) { controller.start() }
                .buttonStyle(DFButtonStyle(height: 28))
        case .idle:
            Button(L10n.qrPairStart()) { controller.start() }
                .buttonStyle(DFButtonStyle(height: 28))
        }
    }
}
