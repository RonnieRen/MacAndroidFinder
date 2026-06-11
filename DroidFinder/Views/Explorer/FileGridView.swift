import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FileGridView
//
// Grid view from the redesign: ~4 columns, 148px thumbnail wells, name +
// size below. Shares selection semantics, drag-out, context menus, drop
// handling and the thumbnail store with the list view.

struct FileGridView: View {
    let files: [DroidFileItem]
    let isSearching: Bool
    @Binding var fileSelection: Set<String>
    @Binding var isDropTargeted: Bool
    let dropTargetDirectoryPath: String
    @ObservedObject var thumbnailStore: ThumbnailStore
    let deviceSerial: String?

    let onOpenDirectory: (String) -> Void
    let onOpenInApp: (DroidFileItem) -> Void
    let onDownloadItem: (DroidFileItem) -> Void
    let onDeleteItem: (DroidFileItem) -> Void
    let onDownloadSelection: () -> Void
    let onDeleteSelection: () -> Void
    let onDropProviders: ([NSItemProvider]) -> Bool
    let dragItemProviders: ([DroidFileItem]) -> [NSPasteboardWriting]

    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 320), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(files) { item in
                    FileGridCellView(
                        item: item,
                        isSelected: fileSelection.contains(item.id),
                        selectionCount: fileSelection.count,
                        thumbnail: thumbnailStore.images[item.id],
                        onClick: { handleClick(item: item) },
                        onDoubleClick: { handleDoubleClick(item: item) },
                        onOpenDirectory: { onOpenDirectory(item.fullPath) },
                        onOpenInApp: { onOpenInApp(item) },
                        onDownloadItem: { onDownloadItem(item) },
                        onDeleteItem: { onDeleteItem(item) },
                        onDownloadSelection: onDownloadSelection,
                        onDeleteSelection: onDeleteSelection,
                        dragProvidersForThisDrag: { providersForDrag(of: item) }
                    )
                    .onAppear {
                        if let deviceSerial {
                            thumbnailStore.request(item: item, deviceSerial: deviceSerial)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(DFTheme.winBG)
        .overlay {
            if files.isEmpty {
                Text(isSearching ? L10n.emptySearchResult() : L10n.emptyDirectory())
                    .font(.system(size: 13))
                    .foregroundStyle(DFTheme.ink3)
            }
        }
        .overlay {
            if isDropTargeted {
                FileDropOverlay(targetPath: dropTargetDirectoryPath)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            onDropProviders(providers)
        }
    }

    // MARK: - Selection (same semantics as the list)

    private func providersForDrag(of item: DroidFileItem) -> [NSPasteboardWriting] {
        if fileSelection.contains(item.id) && fileSelection.count > 1 {
            let chosen = files.filter { fileSelection.contains($0.id) }
            return dragItemProviders(chosen)
        }
        return dragItemProviders([item])
    }

    private func handleDoubleClick(item: DroidFileItem) {
        if item.isDirectory {
            onOpenDirectory(item.fullPath)
        } else {
            onOpenInApp(item)
        }
    }

    private func handleClick(item: DroidFileItem) {
        FileTableView.applyClickSelection(item: item, files: files, selection: &fileSelection)
    }
}

// MARK: - FileGridCellView

private struct FileGridCellView: View {
    let item: DroidFileItem
    let isSelected: Bool
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbWell

            Text(item.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? DFTheme.selectedInk : DFTheme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.top, 8)
                .finderHoverTooltip(item.name, enabled: isHovering || isSelected)

            Text(metaText)
                .font(.system(size: 11))
                .foregroundStyle(DFTheme.ink3)
                .monospacedDigit()
                .padding(.top, 2)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? DFTheme.accentSoft : (isHovering ? DFTheme.hoverBG : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onClick() }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onDoubleClick() })
        .contextMenu { contextMenuContent }
        .background(
            MultiItemDragOverlay(providersProvider: dragProvidersForThisDrag)
        )
    }

    private var thumbWell: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? DFTheme.accentSoft2 : DFTheme.fieldBG)
            .frame(height: 148)
            .overlay {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                        .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 30))
                        .foregroundStyle(item.isDirectory ? DFTheme.accent : DFTheme.ink3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        switch item.type {
        case .directory: return "folder.fill"
        case .file: return ImagePreviewService.isImage(item.name) ? "photo" : "doc"
        case .symlink: return "arrow.triangle.branch"
        case .unknown: return "questionmark.square"
        }
    }

    private var metaText: String {
        if item.isDirectory { return L10n.folder() }
        guard let bytes = Int64(item.sizeDescription) else { return item.sizeDescription }
        return DeviceDetail.formatBytes(bytes)
    }

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
