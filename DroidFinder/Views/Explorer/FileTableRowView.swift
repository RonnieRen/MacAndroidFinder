import AppKit
import SwiftUI

// MARK: - FileTableRowView
//
// One 46px row: 30px thumbnail (real image when ThumbnailStore has one),
// name with hover tooltip, size + modified columns. Hover, selection,
// double-click, context menu and drag-out included.

struct FileTableRowView: View {
    let item: DroidFileItem
    let isSelected: Bool
    /// Total number of selected rows (for multi-select context-menu items).
    let selectionCount: Int
    let thumbnail: NSImage?
    let onClick: () -> Void
    let onDoubleClick: () -> Void
    let onOpenDirectory: () -> Void
    let onOpenInApp: () -> Void
    let onDownloadItem: () -> Void
    let onDeleteItem: () -> Void
    let onDownloadSelection: () -> Void
    let onDeleteSelection: () -> Void
    let dragProvidersForThisDrag: () -> [NSPasteboardWriting]

    @State private var isHovering = false

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        df.doesRelativeDateFormatting = true
        return df
    }()

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 11) {
                thumbnailView
                Text(item.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DFTheme.selectedInk : DFTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .finderHoverTooltip(item.name, enabled: isHovering || isSelected)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(sizeText)
                .frame(width: 90, alignment: .trailing)
            Text(dateText)
                .frame(width: 150, alignment: .trailing)
                .padding(.trailing, 4)
        }
        .font(.system(size: 12))
        .foregroundStyle(isSelected ? DFTheme.selectedInk2 : DFTheme.ink2)
        .monospacedDigit()
        .padding(.horizontal, 6)
        .frame(height: DFTheme.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: DFTheme.controlRadius)
                .fill(isSelected ? DFTheme.accentSoft : (isHovering ? DFTheme.hoverBG : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onClick() }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onDoubleClick() })
        .contextMenu { contextMenuContent }
        // AppKit overlay so multi-selection drags carry every selected
        // NSFilePromiseProvider (SwiftUI .onDrag exports only one).
        .background(
            MultiItemDragOverlay(providersProvider: dragProvidersForThisDrag)
        )
    }

    // MARK: - Cells

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(item.isDirectory ? DFTheme.accentSoft : DFTheme.fieldBG)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 13))
                        .foregroundStyle(item.isDirectory ? DFTheme.accent : DFTheme.ink3)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
        }
    }

    private var iconName: String {
        switch item.type {
        case .directory: return "folder.fill"
        case .file: return ImagePreviewService.isImage(item.name) ? "photo" : "doc"
        case .symlink: return "arrow.triangle.branch"
        case .unknown: return "questionmark.square"
        }
    }

    private var sizeText: String {
        if item.isDirectory { return "—" }
        guard let bytes = Int64(item.sizeDescription) else { return item.sizeDescription }
        return DeviceDetail.formatBytes(bytes)
    }

    private var dateText: String {
        guard let date = item.modifiedDate else { return "—" }
        return Self.dateFormatter.string(from: date)
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuContent: some View {
        if isSelected && selectionCount > 1 {
            Button(L10n.saveSelectedToMac(selectionCount), action: onDownloadSelection)
            Button(L10n.deleteSelectedItems(selectionCount), role: .destructive, action: onDeleteSelection)
            Divider()
        }
        if item.isDirectory {
            Button(L10n.openDirectory(), action: onOpenDirectory)
            Button(L10n.downloadDirectory(), action: onDownloadItem)
            Button(L10n.deleteFolder(), role: .destructive, action: onDeleteItem)
        } else {
            Button(L10n.openFile(), action: onOpenInApp)
            Button(L10n.downloadFile(), action: onDownloadItem)
            Button(L10n.deleteFile(), role: .destructive, action: onDeleteItem)
        }
    }
}
