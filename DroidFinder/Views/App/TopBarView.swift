import SwiftUI

// MARK: - TopBarView
//
// Top toolbar: device picker, refresh button, wireless-connect sheet trigger,
// and (when a single file is selected) quick download / delete actions.

struct TopBarView: View {
    let devices: [DroidDevice]
    let selectedDevice: DroidDevice?
    let onDeviceSelected: (DroidDevice?) -> Void
    let onRefresh: () -> Void
    let selectedFile: DroidFileItem?
    let onOpenWireless: () -> Void
    let onDownloadItem: (DroidFileItem) -> Void
    let onDeleteItem: (DroidFileItem) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Picker(L10n.deviceLabel(), selection: Binding(
                get: { selectedDevice?.id ?? "" },
                set: { newID in
                    onDeviceSelected(devices.first(where: { $0.id == newID }))
                }
            )) {
                ForEach(devices) { device in
                    Text(device.displayName).tag(device.id)
                }
            }
            .frame(maxWidth: 320)

            Button(L10n.refreshDevices(), action: onRefresh)

            Spacer()

            Button(L10n.wirelessConnect(), action: onOpenWireless)

            if let selectedFile {
                if !selectedFile.isDirectory {
                    Button(L10n.downloadFile()) {
                        onDownloadItem(selectedFile)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(L10n.deleteFile(), role: .destructive) {
                        onDeleteItem(selectedFile)
                    }
                }
            }
        }
    }
}
