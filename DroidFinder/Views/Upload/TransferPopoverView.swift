import SwiftUI

// MARK: - TransferPopoverView
//
// 372px transfer popover from the redesign, anchored top-right under the
// toolbar. Rows: direction badge (accent = download, green = upload), file
// name, progress bar, "1.5 MB / 2.4 MB · 12.6 MB/s · 保存到 ~/Downloads",
// cancel ✕ while active, ✓ when done. Footer: clear finished.

struct TransferPopoverView: View {
    @ObservedObject var store: TransferQueueStore
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.tasks) { task in
                        row(task)
                    }
                }
            }
            .frame(maxHeight: 300)

            footer
        }
        .frame(width: 372)
        .background(
            RoundedRectangle(cornerRadius: DFTheme.radius)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.20), radius: 20, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DFTheme.radius)
                .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
        )
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack {
            Text(L10n.transfersTitle())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DFTheme.ink)
            Spacer()
            Text(L10n.transferHeadSummary(store.runningCount, store.pendingCount, store.finishedCount))
                .font(.system(size: 11))
                .foregroundStyle(DFTheme.ink3)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DFTheme.ink3)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            DFTheme.lineSoft.frame(height: 1)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(L10n.clearFinished()) {
                store.clearFinished()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(store.finishedCount > 0 ? DFTheme.accent : DFTheme.ink3)
            .disabled(store.finishedCount == 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            DFTheme.lineSoft.frame(height: 1)
        }
    }

    // MARK: - Row

    private func row(_ task: TransferTaskItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            directionBadge(task)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DFTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if task.status == .running || task.status == .pending {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(red: 0xEC / 255, green: 0xEC / 255, blue: 0xF0 / 255))
                            Capsule()
                                .fill(task.direction == .download ? DFTheme.accent : DFTheme.green)
                                .frame(width: geo.size.width * task.progress)
                        }
                    }
                    .frame(height: 4)
                }

                Text(metaText(task))
                    .font(.system(size: 11))
                    .foregroundStyle(DFTheme.ink3)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            trailing(task)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            DFTheme.lineSoft.frame(height: 1).padding(.leading, 14)
        }
    }

    private func directionBadge(_ task: TransferTaskItem) -> some View {
        Circle()
            .fill(task.direction == .download ? DFTheme.accentSoft : Color(red: 0xEA / 255, green: 0xF7 / 255, blue: 0xF0 / 255))
            .frame(width: 20, height: 20)
            .overlay {
                Image(systemName: task.direction == .download ? "arrow.down" : "arrow.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(task.direction == .download ? DFTheme.accent : DFTheme.green)
            }
    }

    @ViewBuilder
    private func trailing(_ task: TransferTaskItem) -> some View {
        switch task.status {
        case .pending, .running:
            Button {
                store.cancel(taskID: task.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DFTheme.ink3)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .completed:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(DFTheme.green)
                .frame(width: 24, height: 24)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(DFTheme.red)
                .frame(width: 24, height: 24)
        case .cancelled:
            Image(systemName: "slash.circle")
                .font(.system(size: 13))
                .foregroundStyle(DFTheme.ink3)
                .frame(width: 24, height: 24)
        }
    }

    // MARK: - Meta line

    private func metaText(_ task: TransferTaskItem) -> String {
        let sizeText = task.totalBytes.map(DeviceDetail.formatBytes)

        switch task.status {
        case .pending:
            return [sizeText, L10n.queuedLabel()].compactMap { $0 }.joined(separator: " · ")
        case .running:
            var parts: [String] = []
            if let total = task.totalBytes, let done = task.transferredBytes {
                parts.append("\(DeviceDetail.formatBytes(done)) / \(DeviceDetail.formatBytes(total))")
            }
            if let speed = task.speedBytesPerSec {
                parts.append(DeviceDetail.formatBytes(Int64(speed)) + "/s")
            }
            parts.append(task.direction == .download
                         ? L10n.saveDest(task.destinationDisplay)
                         : L10n.sendDest(task.destinationDisplay))
            return parts.joined(separator: " · ")
        case .completed:
            let dest = task.direction == .download
                ? L10n.savedDest(task.destinationDisplay)
                : L10n.sentDest(task.destinationDisplay)
            return [sizeText, dest].compactMap { $0 }.joined(separator: " · ")
        case .failed(let message):
            return message
        case .cancelled:
            return [sizeText, L10n.cancelledLabel()].compactMap { $0 }.joined(separator: " · ")
        }
    }
}
