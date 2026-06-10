import SwiftUI

// MARK: - UploadQueuePanelView
//
// Floating bottom-right panel summarising the active upload queue.

struct UploadQueuePanelView: View {
    let uploadQueue: [UploadTaskItem]
    let progress: Double
    let onClearFinished: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ProgressView(value: progress)
                .controlSize(.small)
            taskList
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text(L10n.uploadQueue())
                .font(.headline)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help(L10n.close())
            Text("\(completedCount)/\(uploadQueue.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(L10n.clearFinished(), action: onClearFinished)
                .disabled(uploadQueue.allSatisfy { $0.status == .pending || $0.status == .uploading })
        }
    }

    private var taskList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(uploadQueue) { task in
                    taskRow(task)
                }
            }
        }
        .frame(maxHeight: 130)
    }

    private func taskRow(_ task: UploadTaskItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName(for: task.status))
                .foregroundStyle(color(for: task.status))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.fileName)
                    .lineLimit(1)
                Text(task.remoteDirectory)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if task.status == .uploading {
                ProgressView(value: task.progress)
                    .controlSize(.small)
                    .frame(width: 56)
                Text("\(Int(task.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(task.status.title)
                .font(.caption)
                .foregroundStyle(color(for: task.status))
            if let detail = task.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private var completedCount: Int {
        uploadQueue.filter { $0.status == .completed || $0.status == .failed }.count
    }

    private func iconName(for status: UploadTaskStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .uploading: return "arrow.up.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }

    private func color(for status: UploadTaskStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .uploading: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
