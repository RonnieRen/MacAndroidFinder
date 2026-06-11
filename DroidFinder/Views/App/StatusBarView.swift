import SwiftUI

// MARK: - StatusBarView
//
// 30px bottom status bar: item / selection summary on the left; device name,
// free space and the transient status message on the right.

struct StatusBarView: View {
    let itemCount: Int
    let selectionCount: Int
    let selectionBytes: Int64?
    let deviceName: String?
    let freeBytes: Int64?
    let isBusy: Bool
    let statusMessage: String
    /// "正在传输 2 项 · 12.6 MB/s" while the queue is active.
    let transferSummary: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.itemsCount(itemCount))
            if selectionCount > 0 {
                dotSep
                Text(L10n.selectedSummary(selectionCount, selectionBytes.map(DeviceDetail.formatBytes)))
            }
            if isBusy || !statusMessage.isEmpty {
                dotSep
                if isBusy {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text(statusMessage)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            if let transferSummary {
                Text(transferSummary)
                    .foregroundStyle(DFTheme.accent)
                dotSep
            }
            if let deviceName {
                Text(deviceName)
                if let freeBytes {
                    dotSep
                    Text(L10n.freeSpace(DeviceDetail.formatBytes(freeBytes)))
                }
            } else {
                Text(L10n.notConnected())
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(DFTheme.ink2)
        .padding(.horizontal, 16)
        .frame(height: DFTheme.statusBarHeight)
        .background(DFTheme.barBG)
        .overlay(alignment: .top) {
            DFTheme.line.frame(height: 1)
        }
    }

    private var dotSep: some View {
        Circle()
            .fill(Color(red: 0xC5 / 255, green: 0xC5 / 255, blue: 0xCC / 255))
            .frame(width: 2, height: 2)
    }
}
