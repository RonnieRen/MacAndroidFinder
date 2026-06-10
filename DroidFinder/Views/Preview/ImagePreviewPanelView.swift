import SwiftUI

// MARK: - ImagePreviewPanelView
//
// Third HSplit pane that shows a quick image preview for the currently
// selected file (when it is an image).

struct ImagePreviewPanelView: View {
    @ObservedObject var service: ImagePreviewService
    let item: DroidFileItem
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(item.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.close())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if service.isLoading {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text("Loading…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else if let image = service.previewImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
        } else if let error = service.previewError {
            Spacer()
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        } else {
            Spacer()
        }
    }
}
