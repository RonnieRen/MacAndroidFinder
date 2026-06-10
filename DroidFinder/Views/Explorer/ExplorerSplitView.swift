import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ExplorerSplitView
//
// The 2- or 3-pane explorer body: a sidebar with the directory tree, the file
// list (with toolbar + column header), and an optional image preview pane.

struct ExplorerSplitView: View {
    let directoryRoots: [RemoteDirectoryNode]
    @Binding var selectedSidebarPath: String?
    let files: [DroidFileItem]
    @Binding var fileSelection: Set<String>
    @Binding var isEditMode: Bool
    @Binding var selectedEditItemIDs: Set<String>
    @Binding var isDropTargeted: Bool
    let dropTargetDirectoryPath: String
    let onSelectDirectory: (String) -> Void
    let childrenForDirectory: (String) -> [RemoteDirectoryNode]
    let isDirectoryLoading: (String) -> Bool
    let onExpandDirectory: (String) -> Void
    let onUploadHere: () -> Void
    let onToggleEditMode: () -> Void
    let onDeleteSelected: () -> Void
    let onDownloadItem: (DroidFileItem) -> Void
    let onDeleteItem: (DroidFileItem) -> Void
    let onDropProviders: ([NSItemProvider]) -> Bool
    let onOpenInApp: (DroidFileItem) -> Void
    /// Provides one drag-out promise per remote file. We use
    /// NSFilePromiseProvider under the hood because Finder requires the
    /// promise pasteboard protocol for on-demand file drops.
    let dragItemProviders: ([DroidFileItem]) -> [NSPasteboardWriting]
    let previewService: ImagePreviewService
    let previewItem: DroidFileItem?
    let onClosePreview: (String) -> Void

    @StateObject private var columnWidths = ColumnWidths()

    var body: some View {
        HSplitView {
            sidebar
            fileListPane
            if let item = previewItem {
                ImagePreviewPanelView(
                    service: previewService,
                    item: item,
                    onClose: { onClosePreview(item.id) }
                )
                .frame(minWidth: 200, idealWidth: 300)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List {
            Section(L10n.directoryTree()) {
                ForEach(directoryRoots) { root in
                    DirectoryTreeNodeView(
                        node: root,
                        level: 0,
                        selectedPath: $selectedSidebarPath,
                        childProvider: childrenForDirectory,
                        loadingProvider: isDirectoryLoading,
                        onSelect: onSelectDirectory,
                        onExpand: onExpandDirectory
                    )
                }
            }
        }
        .frame(minWidth: 260, idealWidth: 300)
    }

    // MARK: - File list pane

    private var fileListPane: some View {
        VStack(spacing: 8) {
            actionsBar
            ExplorerColumnHeaderView(isEditMode: isEditMode, widths: columnWidths)
            fileList
        }
    }

    private var actionsBar: some View {
        HStack {
            if isEditMode {
                Text(L10n.selectedCount(selectedEditItemIDs.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(isEditMode ? L10n.done() : L10n.editMode(), action: onToggleEditMode)
            if isEditMode {
                Button(L10n.deleteSelected(), action: onDeleteSelected)
                    .disabled(selectedEditItemIDs.isEmpty)
            }
            Button(action: onUploadHere) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isEditMode)
            .help(L10n.uploadHere())
            .accessibilityLabel(L10n.uploadHere())
        }
    }

    private var fileList: some View {
        List {
            ForEach(files) { item in
                ExplorerFileRowView(
                    item: item,
                    isEditMode: isEditMode,
                    isSelected: selectedEditItemIDs.contains(item.id),
                    isHighlighted: fileSelection.contains(item.id),
                    columnWidths: columnWidths,
                    onToggleSelection: { toggleSelection(id: item.id) },
                    onRowClick: { handleRowClick(item: item) },
                    onOpenDirectory: { onSelectDirectory(item.fullPath) },
                    onDownloadItem: { onDownloadItem(item) },
                    onDeleteItem: { onDeleteItem(item) },
                    onOpenInApp: { onOpenInApp(item) },
                    dragProvidersForThisDrag: {
                        // If this row is part of a multi-selection, drag the
                        // whole selection; otherwise just this row.
                        if fileSelection.contains(item.id) && fileSelection.count > 1 {
                            let chosen = files.filter { fileSelection.contains($0.id) }
                            return dragItemProviders(chosen)
                        } else {
                            return dragItemProviders([item])
                        }
                    }
                )
                // Always set a listRowBackground with the SAME view type for
                // selected and unselected rows so List gives every row
                // identical height.
                .listRowBackground(
                    Rectangle().fill(
                        fileSelection.contains(item.id)
                            ? Color.accentColor.opacity(0.25)
                            : Color.clear
                    )
                )
            }
        }
        .overlay {
            if files.isEmpty {
                Text(L10n.emptyDirectory())
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .topLeading) {
            if isDropTargeted {
                Text(L10n.dropToUpload(dropTargetDirectoryPath))
                    .font(.caption)
                    .padding(8)
                    .background(.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(8)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            onDropProviders(providers)
        }
    }

    // MARK: - Selection helpers

    private func toggleSelection(id: String) {
        if selectedEditItemIDs.contains(id) {
            selectedEditItemIDs.remove(id)
        } else {
            selectedEditItemIDs.insert(id)
        }
    }

    /// Handle a click on a file row. Implements standard macOS selection:
    /// - Plain click: replace selection with this one item
    /// - Cmd-click: toggle this item in/out of the selection
    /// - Shift-click: extend selection to a contiguous range from the last
    ///   selected anchor through this item
    private func handleRowClick(item: DroidFileItem) {
        let mods = NSEvent.modifierFlags
        let isCmd = mods.contains(.command)
        let isShift = mods.contains(.shift)

        if isCmd {
            if fileSelection.contains(item.id) {
                fileSelection.remove(item.id)
            } else {
                fileSelection.insert(item.id)
            }
            return
        }

        if isShift, let anchor = fileSelection.first,
           let anchorIdx = files.firstIndex(where: { $0.id == anchor }),
           let targetIdx = files.firstIndex(where: { $0.id == item.id }) {
            let range = anchorIdx <= targetIdx
                ? files[anchorIdx...targetIdx]
                : files[targetIdx...anchorIdx]
            fileSelection = Set(range.map { $0.id })
            return
        }

        fileSelection = [item.id]
    }
}
