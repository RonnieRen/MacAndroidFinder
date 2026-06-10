import SwiftUI

// MARK: - WirelessConnectionSheet
//
// Modal sheet for wireless ADB workflows: USB-to-Wi-Fi quick switch, mDNS
// device discovery, pair-with-code, and manual endpoint connect.

struct WirelessConnectionSheet: View {
    @ObservedObject var viewModel: DroidFinderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pairEndpoint = ""
    @State private var pairCode = ""
    @State private var connectEndpoint = ""
    @State private var manualEndpoint = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            usbQuickConnectGroup
            QRPairingView(controller: viewModel.qrPairingController)
            nearbyDevicesGroup

            HStack(alignment: .top, spacing: 12) {
                pairWithCodeGroup
                manualConnectGroup
            }
        }
        .padding(16)
        .task {
            if viewModel.wirelessServices.isEmpty {
                await viewModel.discoverWirelessServices()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text(L10n.wirelessConnectTitle())
                .font(.title3.bold())
            Spacer()
            if viewModel.isWirelessBusy {
                ProgressView()
                    .controlSize(.small)
            }
            Button(L10n.close()) { dismiss() }
        }
    }

    private var usbQuickConnectGroup: some View {
        GroupBox(L10n.usbQuickConnect()) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.usbQuickConnectHint())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(viewModel.selectedDevice?.displayName ?? L10n.noUSBDeviceSelected())
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.connectUsingUSB()) {
                        Task { await viewModel.quickConnectSelectedDeviceViaWiFi() }
                    }
                    .disabled(viewModel.selectedDevice == nil || (viewModel.selectedDevice?.id.contains(":") ?? false))
                }
            }
            .padding(.top, 2)
        }
    }

    private var nearbyDevicesGroup: some View {
        GroupBox(L10n.nearbyDevices()) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(L10n.discover()) {
                        Task { await viewModel.discoverWirelessServices() }
                    }
                    Spacer()
                }

                if viewModel.wirelessServices.isEmpty {
                    Text(L10n.noNearbyDevices())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    nearbyDevicesList
                }
            }
            .padding(.top, 2)
        }
    }

    private var nearbyDevicesList: some View {
        List(viewModel.wirelessServices) { service in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                    Text("\(service.type) • \(service.endpoint)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.connect()) {
                    Task { await viewModel.connectWireless(endpoint: service.endpoint) }
                }
                Button(L10n.disconnect()) {
                    Task { await viewModel.disconnectWireless(endpoint: service.endpoint) }
                }
            }
        }
        .frame(height: 140)
    }

    private var pairWithCodeGroup: some View {
        GroupBox(L10n.pairWithCode()) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(L10n.pairEndpoint(), text: $pairEndpoint)
                TextField(L10n.pairCode(), text: $pairCode)
                TextField(L10n.connectEndpoint(), text: $connectEndpoint)
                Button(L10n.pairAndConnect()) {
                    Task {
                        await viewModel.pairAndConnect(
                            pairEndpoint: pairEndpoint,
                            pairCode: pairCode,
                            connectEndpoint: connectEndpoint
                        )
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.top, 2)
        }
    }

    private var manualConnectGroup: some View {
        GroupBox(L10n.manualConnect()) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(L10n.endpoint(), text: $manualEndpoint)
                HStack {
                    Button(L10n.connect()) {
                        Task { await viewModel.connectWireless(endpoint: manualEndpoint) }
                    }
                    Button(L10n.disconnect()) {
                        Task { await viewModel.disconnectWireless(endpoint: manualEndpoint) }
                    }
                    Button(L10n.disconnectAll()) {
                        Task { await viewModel.disconnectWireless(endpoint: nil) }
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.top, 2)
        }
    }
}
