import AppKit
import SwiftUI

// MARK: - PreviewPanelView
//
// 292px right panel from the redesign: large preview (image when available,
// icon placeholder otherwise), file name, metadata table, and the action
// stack (Save to Mac primary; Share / Open / Delete row).

struct PreviewPanelView: View {
    @ObservedObject var previewService: ImagePreviewService
    let item: DroidFileItem
    let onSaveToMac: () -> Void
    let onShare: (NSView) -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            previewArea
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .padding(.bottom, 16)

            Text(item.name)
                .font(.system(size: 13, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(DFTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            metaTable

            Spacer(minLength: 12)

            actions
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(width: DFTheme.previewWidth)
        .background(DFTheme.previewBG)
        .overlay(alignment: .leading) {
            DFTheme.line.frame(width: 1)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 8)

            if let image = previewService.previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(4)
            } else if previewService.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                    .font(.system(size: 44))
                    .foregroundStyle(DFTheme.ink3.opacity(0.6))
            }
        }
        .frame(width: 200, height: 240)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Metadata

    private var metaTable: some View {
        VStack(spacing: 0) {
            metaRow(L10n.typeLabel(), typeText)
            if let dims = dimensionsText {
                metaRow(L10n.dimensionsLabel(), dims)
            }
            metaRow(L10n.sizeLabel(), sizeText)
            metaRow(L10n.modifiedLabel(), modifiedText)
        }
        .overlay(alignment: .top) {
            DFTheme.lineSoft.frame(height: 1)
        }
    }

    private func metaRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(DFTheme.ink3)
            Spacer()
            Text(value)
                .foregroundStyle(DFTheme.ink2)
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            DFTheme.lineSoft.frame(height: 1)
        }
    }

    private var typeText: String {
        if item.isDirectory { return L10n.folder() }
        let ext = (item.name as NSString).pathExtension.uppercased()
        guard !ext.isEmpty else { return L10n.file() }
        return ImagePreviewService.isImage(item.name) ? L10n.imageType(ext) : L10n.fileTypeDesc(ext)
    }

    private var dimensionsText: String? {
        guard let image = previewService.previewImage,
              let rep = image.representations.first,
              rep.pixelsWide > 0 else { return nil }
        return "\(rep.pixelsWide) × \(rep.pixelsHigh)"
    }

    private var sizeText: String {
        if item.isDirectory { return "—" }
        guard let bytes = Int64(item.sizeDescription) else { return item.sizeDescription }
        return DeviceDetail.formatBytes(bytes)
    }

    private var modifiedText: String {
        guard let date = item.modifiedDate else { return "—" }
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm"
        return df.string(from: date)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 8) {
            Button(action: onSaveToMac) {
                Label(L10n.saveToMac(), systemImage: "arrow.down.to.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DFButtonStyle(isPrimary: true, height: 36))

            HStack(spacing: 8) {
                ShareAnchorButton(title: L10n.share(), onShare: onShare)
                Button(L10n.openFile()) { onOpen() }
                    .buttonStyle(DFButtonStyle(height: 32))
                    .frame(maxWidth: .infinity)
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text(L10n.deleteItem())
                        .foregroundStyle(DFTheme.red)
                }
                .buttonStyle(DFButtonStyle(height: 32))
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - ShareAnchorButton
//
// NSSharingServicePicker must be anchored to an NSView, so the share button
// hands its backing view to the callback.

private struct ShareAnchorButton: View {
    let title: String
    let onShare: (NSView) -> Void

    var body: some View {
        ShareAnchorRepresentable(title: title, onShare: onShare)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
    }
}

private struct ShareAnchorRepresentable: NSViewRepresentable {
    let title: String
    let onShare: (NSView) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.didClick(_:)))
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.title = title
        context.coordinator.onShare = onShare
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onShare: onShare)
    }

    final class Coordinator: NSObject {
        var onShare: (NSView) -> Void

        init(onShare: @escaping (NSView) -> Void) {
            self.onShare = onShare
        }

        @objc func didClick(_ sender: NSButton) {
            onShare(sender)
        }
    }
}
