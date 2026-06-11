import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FileTableView
//
// Redesigned file table: 34px column header (Name / Size / Modified), 46px
// rows with thumbnails, accent-soft selection, lazy scrolling, Finder-style
// multi-select (cmd / shift click), drag-out, context menus, and the dashed
// drag-in drop overlay.

struct FileTableView: View {
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

    var body: some View {
        VStack(spacing: 0) {
            header
            rows
        }
        .background(DFTheme.winBG)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text(L10n.nameColumn())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.sizeColumn())
                .frame(width: 90, alignment: .trailing)
            HStack(spacing: 3) {
                Text(L10n.modifiedColumn())
                    .foregroundStyle(DFTheme.ink)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(DFTheme.ink)
            }
            .frame(width: 150, alignment: .trailing)
            .padding(.trailing, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(DFTheme.ink3)
        .padding(.horizontal, 14)
        .frame(height: DFTheme.tableHeaderHeight)
        .overlay(alignment: .bottom) {
            DFTheme.lineSoft.frame(height: 1)
        }
    }

    // MARK: - Rows

    private var rows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(files) { item in
                    FileTableRowView(
                        item: item,
                        isSelected: fileSelection.contains(item.id),
                        selectionCount: fileSelection.count,
                        thumbnail: thumbnailStore.images[item.id],
                        onClick: { handleRowClick(item: item) },
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
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

    // MARK: - Selection / activation

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

    /// Standard macOS selection: plain click replaces, cmd toggles,
    /// shift extends a contiguous range from the anchor.
    private func handleRowClick(item: DroidFileItem) {
        Self.applyClickSelection(item: item, files: files, selection: &fileSelection)
    }

    /// Shared by list and grid so both views select identically.
    static func applyClickSelection(item: DroidFileItem, files: [DroidFileItem], selection: inout Set<String>) {
        let mods = NSEvent.modifierFlags

        if mods.contains(.command) {
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
            return
        }

        if mods.contains(.shift), let anchor = selection.first,
           let anchorIdx = files.firstIndex(where: { $0.id == anchor }),
           let targetIdx = files.firstIndex(where: { $0.id == item.id }) {
            let range = anchorIdx <= targetIdx
                ? files[anchorIdx...targetIdx]
                : files[targetIdx...anchorIdx]
            selection = Set(range.map { $0.id })
            return
        }

        selection = [item.id]
    }
}

// MARK: - FileDropOverlay

/// Dashed accent drop overlay shared by the list and grid views.
struct FileDropOverlay: View {
    let targetPath: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DFTheme.radius)
                .fill(DFTheme.accentSoft.opacity(0.86))
            RoundedRectangle(cornerRadius: DFTheme.radius)
                .strokeBorder(DFTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            VStack(spacing: 5) {
                Circle()
                    .fill(DFTheme.accent)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: DFTheme.accent.opacity(0.35), radius: 10, y: 8)
                    .padding(.bottom, 10)
                Text(L10n.dropToUpload(targetPath))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DFTheme.selectedInk)
            }
        }
        .padding(10)
        .allowsHitTesting(false)
    }
}
