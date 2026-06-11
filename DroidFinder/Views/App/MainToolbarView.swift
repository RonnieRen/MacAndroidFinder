import SwiftUI

// MARK: - MainToolbarView
//
// 60px unified titlebar from the redesign: traffic-light inset, device pill
// (status dot · name · transport · battery), search field, list/grid
// segmented control, "Send to Phone" and primary "Save to Mac" buttons.

struct MainToolbarView: View {
    let devices: [DroidDevice]
    let selectedDevice: DroidDevice?
    let deviceDetail: DeviceDetail?
    let isOffline: Bool
    @Binding var searchText: String
    @Binding var viewMode: ExplorerViewMode
    let canSaveToMac: Bool
    /// nil hides the transfer button; otherwise the number of active tasks.
    let transferActiveCount: Int?
    let onSelectDevice: (DroidDevice) -> Void
    let onOpenWireless: () -> Void
    let onRefresh: () -> Void
    let onSendToPhone: () -> Void
    let onSaveToMac: () -> Void
    let onToggleTransfers: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Traffic lights are drawn by the system over this inset.
            Spacer().frame(width: 64)

            devicePill

            Spacer(minLength: 12)

            searchField
                .opacity(isOffline ? 0.45 : 1)
                .disabled(isOffline)
            viewModeSegment
                .opacity(isOffline ? 0.45 : 1)

            if let transferActiveCount {
                transferButton(activeCount: transferActiveCount)
            }

            Button(action: onSendToPhone) {
                Label(L10n.sendToPhone(), systemImage: "arrow.up.to.line")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(DFButtonStyle())
            .disabled(isOffline)
            .opacity(isOffline ? 0.45 : 1)

            Button(action: onSaveToMac) {
                Label(L10n.saveToMac(), systemImage: "arrow.down.to.line")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(DFButtonStyle(isPrimary: true))
            .disabled(isOffline || !canSaveToMac)
            .opacity(isOffline || !canSaveToMac ? 0.45 : 1)
        }
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(height: DFTheme.toolbarHeight)
        .background(DFTheme.barBG)
        .overlay(alignment: .bottom) {
            DFTheme.line.frame(height: 1)
        }
    }

    // MARK: - Device pill

    private var devicePill: some View {
        Menu {
            ForEach(devices) { device in
                Button {
                    onSelectDevice(device)
                } label: {
                    if device.id == selectedDevice?.id {
                        Label(device.displayName, systemImage: "checkmark")
                    } else {
                        Text(device.displayName)
                    }
                }
            }
            if !devices.isEmpty {
                Divider()
            }
            Button(L10n.wirelessConnect() + "…", action: onOpenWireless)
            Button(L10n.refreshDevices(), action: onRefresh)
        } label: {
            pillLabel
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var pillLabel: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(isOffline ? Color(red: 0xB9 / 255, green: 0xB9 / 255, blue: 0xC2 / 255) : DFTheme.green)
                .frame(width: 7, height: 7)
                .shadow(color: (isOffline ? Color.black.opacity(0.05) : DFTheme.green.opacity(0.3)), radius: 2)

            Text(selectedDevice?.displayName ?? L10n.notConnected())
                .font(.system(size: 13, weight: isOffline ? .medium : .semibold))
                .foregroundStyle(isOffline ? DFTheme.ink2 : DFTheme.ink)
                .lineLimit(1)

            if let selectedDevice {
                Rectangle()
                    .fill(DFTheme.line)
                    .frame(width: 1, height: 16)

                HStack(spacing: 4) {
                    Image(systemName: selectedDevice.id.contains(":") ? "wifi" : "cable.connector")
                        .font(.system(size: 10))
                    Text(selectedDevice.id.contains(":") ? "Wi-Fi" : "USB")
                }
                .font(.system(size: 11))
                .foregroundStyle(DFTheme.ink2)

                if let battery = deviceDetail?.batteryLevel {
                    Text("\(battery)%")
                        .font(.system(size: 11))
                        .foregroundStyle(DFTheme.ink2)
                }
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(DFTheme.ink3)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DFTheme.winBG)
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(DFTheme.line, lineWidth: 1)
        )
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DFTheme.ink3)
            TextField(L10n.searchThisFolder(), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DFTheme.ink3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(width: 220, height: 32)
        .background(
            RoundedRectangle(cornerRadius: DFTheme.controlRadius)
                .fill(DFTheme.fieldBG)
        )
    }

    // MARK: - Transfer button

    private func transferButton(activeCount: Int) -> some View {
        Button(action: onToggleTransfers) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .medium))
                if activeCount > 0 {
                    Circle()
                        .fill(DFTheme.accent)
                        .frame(width: 6, height: 6)
                        .offset(x: 5, y: -4)
                }
            }
        }
        .buttonStyle(DFIconButtonStyle())
        .help(L10n.transfersTitle())
    }

    // MARK: - View mode segment

    private var viewModeSegment: some View {
        HStack(spacing: 0) {
            segButton(.list, systemImage: "list.bullet", help: L10n.listViewLabel())
            segButton(.grid, systemImage: "square.grid.2x2", help: L10n.gridViewLabel())
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: DFTheme.controlRadius)
                .fill(DFTheme.fieldBG)
        )
    }

    private func segButton(_ mode: ExplorerViewMode, systemImage: String, help: String) -> some View {
        Button {
            viewMode = mode
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(viewMode == mode ? DFTheme.ink : Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x5E / 255))
                .frame(width: 32, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(viewMode == mode ? Color.white : Color.clear)
                        .shadow(color: .black.opacity(viewMode == mode ? 0.08 : 0), radius: 1, y: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - ExplorerViewMode

enum ExplorerViewMode: String {
    case list
    case grid
}
