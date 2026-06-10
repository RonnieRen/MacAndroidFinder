import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView
//
// Top-level window content: top toolbar, breadcrumbs, the explorer split view
// and a status footer, plus various overlays (upload queue panel, wireless
// sheet, error and delete confirmation alerts).

struct ContentView: View {
    @EnvironmentObject var viewModel: DroidFinderViewModel

    /// Multi-select for drag-out (cmd+click / shift+click in file list).
    @State private var fileSelection: Set<String> = []
    @State private var selectedSidebarPath: String?

    @State private var isDropTargeted = false
    /// ID of the item the user explicitly dismissed the preview for.
    /// Selecting a different item clears this so the preview comes back.
    @State private var dismissedPreviewID: String?
    @State private var isUploadQueuePanelVisible = true
    @State private var isWirelessSheetPresented = false
    @State private var pendingDeleteItem: DroidFileItem?
    @State private var isEditMode = false
    @State private var selectedEditItemIDs: Set<String> = []
    @State private var isBulkDeleteConfirmPresented = false

    var body: some View {
        VStack(spacing: 10) {
            topBar
            breadcrumbBar
            Divider()
            explorer
            footer
        }
        .padding(16)
        .overlay { uploadQueueOverlay }
        .onChange(of: viewModel.uploadQueueStore.uploadQueue.isEmpty) { isEmpty in
            if isEmpty { isUploadQueuePanelVisible = true }
        }
        .sheet(isPresented: $isWirelessSheetPresented) {
            WirelessConnectionSheet(viewModel: viewModel)
                .frame(minWidth: 680, minHeight: 480)
        }
        .modifier(ErrorAlertModifier(errorMessage: $viewModel.errorMessage))
        .modifier(
            DeleteOneAlertModifier(
                pendingDeleteItem: $pendingDeleteItem,
                onConfirm: { item in
                    viewModel.delete(item)
                    fileSelection.remove(item.id)
                }
            )
        )
        .modifier(
            DeleteSelectedAlertModifier(
                isPresented: $isBulkDeleteConfirmPresented,
                count: selectedEditItemIDs.count,
                onConfirm: confirmBulkDelete
            )
        )
    }

    // MARK: - Subviews

    private var topBar: some View {
        TopBarView(
            devices: viewModel.devices,
            selectedDevice: viewModel.selectedDevice,
            onDeviceSelected: { device in
                viewModel.selectedDevice = device
                fileSelection = []
                viewModel.imagePreviewService.reset()
                if device != nil {
                    try? viewModel.loadDirectory(path: viewModel.currentPath)
                }
            },
            onRefresh: { Task { await viewModel.refreshDevices() } },
            selectedFile: isEditMode ? nil : selectedFile,
            onOpenWireless: { isWirelessSheetPresented = true },
            onDownloadItem: { viewModel.download($0) },
            onDeleteItem: { pendingDeleteItem = $0 }
        )
    }

    private var breadcrumbBar: some View {
        BreadcrumbBarView(
            breadcrumbs: breadcrumbs,
            canGoParent: viewModel.currentPath != "/",
            onGoParent: {
                viewModel.goParent()
                fileSelection = []
            },
            onNavigate: { openDirectory($0) }
        )
    }

    private var explorer: some View {
        ExplorerSplitView(
            directoryRoots: viewModel.directoryTreeStore.directoryTreeRoots,
            selectedSidebarPath: $selectedSidebarPath,
            files: viewModel.files,
            fileSelection: $fileSelection,
            isEditMode: $isEditMode,
            selectedEditItemIDs: $selectedEditItemIDs,
            isDropTargeted: $isDropTargeted,
            dropTargetDirectoryPath: dropTargetDirectoryPath,
            onSelectDirectory: { openDirectory($0) },
            childrenForDirectory: { viewModel.directoryTreeStore.childrenForDirectory(path: $0) },
            isDirectoryLoading: { viewModel.directoryTreeStore.isDirectoryLoading(path: $0) },
            onExpandDirectory: { viewModel.directoryTreeStore.ensureLoaded(path: $0) },
            onUploadHere: {
                isUploadQueuePanelVisible = true
                viewModel.chooseAndUploadFiles(to: dropTargetDirectoryPath)
            },
            onToggleEditMode: toggleEditMode,
            onDeleteSelected: { isBulkDeleteConfirmPresented = true },
            onDownloadItem: { viewModel.download($0) },
            onDeleteItem: { pendingDeleteItem = $0 },
            onDropProviders: { providers in handleFileDrop(providers) },
            onOpenInApp: { viewModel.openInApp($0) },
            dragItemProviders: { items in viewModel.makeFilePromiseProviders(for: items) },
            previewService: viewModel.imagePreviewService,
            previewItem: previewItem,
            onClosePreview: { id in dismissedPreviewID = id }
        )
        .onChange(of: fileSelection) { newSel in
            let singleID = newSel.count == 1 ? newSel.first : nil
            if let id = singleID,
               let item = viewModel.files.first(where: { $0.id == id }),
               let serial = viewModel.selectedDevice?.id {
                viewModel.imagePreviewService.request(item: item, deviceSerial: serial)
            } else {
                viewModel.imagePreviewService.reset()
            }
        }
    }

    private var footer: some View {
        AppFooterBarView(
            isBusy: viewModel.isBusy || viewModel.uploadQueueStore.isUploading,
            statusMessage: viewModel.statusMessage
        )
    }

    @ViewBuilder
    private var uploadQueueOverlay: some View {
        if shouldShowUploadQueuePanel {
            ZStack(alignment: .bottomTrailing) {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { isUploadQueuePanelVisible = false }

                UploadQueuePanelView(
                    uploadQueue: viewModel.uploadQueueStore.uploadQueue,
                    progress: viewModel.uploadQueueStore.uploadProgress,
                    onClearFinished: { viewModel.uploadQueueStore.clearFinished() },
                    onClose: { isUploadQueuePanelVisible = false }
                )
                .padding(16)
            }
        }
    }

    // MARK: - Derived state

    private var selectedItemID: String? {
        fileSelection.count == 1 ? fileSelection.first : nil
    }

    private var selectedFile: DroidFileItem? {
        guard let selectedItemID else { return nil }
        return viewModel.files.first(where: { $0.id == selectedItemID })
    }

    private var previewItem: DroidFileItem? {
        guard !isEditMode, let f = selectedFile, ImagePreviewService.isImage(f.name) else { return nil }
        if dismissedPreviewID == f.id { return nil }
        return f
    }

    private var breadcrumbs: [(name: String, path: String)] {
        if viewModel.currentPath == "/" {
            return [("/", "/")]
        }

        let components = viewModel.currentPath
            .split(separator: "/")
            .map(String.init)

        var result: [(String, String)] = [("/", "/")]
        var current = ""
        for component in components {
            current += "/\(component)"
            result.append((component, current))
        }
        return result
    }

    private var dropTargetDirectoryPath: String {
        if let selectedFile, selectedFile.isDirectory {
            return selectedFile.fullPath
        }
        return viewModel.currentPath
    }

    private var shouldShowUploadQueuePanel: Bool {
        isUploadQueuePanelVisible && !viewModel.uploadQueueStore.uploadQueue.isEmpty
    }

    // MARK: - Actions

    private func openDirectory(_ path: String) {
        try? viewModel.loadDirectory(path: path)
        selectedSidebarPath = path
        fileSelection = []
    }

    private func toggleEditMode() {
        isEditMode.toggle()
        if !isEditMode {
            selectedEditItemIDs.removeAll()
        } else {
            fileSelection = []
        }
    }

    private func confirmBulkDelete() {
        let selectedItems = viewModel.files.filter { selectedEditItemIDs.contains($0.id) }
        viewModel.delete(items: selectedItems)
        selectedEditItemIDs.removeAll()
        isEditMode = false
        fileSelection = []
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data,
                   let str = String(data: data, encoding: .utf8) {
                    url = URL(string: str.trimmingCharacters(in: .whitespacesAndNewlines))
                } else if let rawURL = item as? URL {
                    url = rawURL
                }

                guard let url else { return }
                DispatchQueue.main.async {
                    isUploadQueuePanelVisible = true
                    viewModel.uploadLocalFiles([url], to: dropTargetDirectoryPath)
                }
            }
        }
        return true
    }
}

// MARK: - Alert modifiers

private struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?

    func body(content: Content) -> some View {
        content.alert(L10n.loadingErrorTitle(), isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button(L10n.ok(), role: .cancel) {}
        } message: {
            Text(errorMessage ?? L10n.unknownError())
        }
    }
}

private struct DeleteOneAlertModifier: ViewModifier {
    @Binding var pendingDeleteItem: DroidFileItem?
    let onConfirm: (DroidFileItem) -> Void

    func body(content: Content) -> some View {
        content.alert(
            L10n.deleteConfirmTitle(),
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { isPresented in if !isPresented { pendingDeleteItem = nil } }
            ),
            presenting: pendingDeleteItem
        ) { item in
            Button(L10n.cancel(), role: .cancel) {
                pendingDeleteItem = nil
            }
            Button(L10n.deleteItem(), role: .destructive) {
                onConfirm(item)
                pendingDeleteItem = nil
            }
        } message: { item in
            Text(item.isDirectory
                 ? L10n.deleteConfirmMessageFolder(item.name)
                 : L10n.deleteConfirmMessage(item.name))
        }
    }
}

private struct DeleteSelectedAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let count: Int
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.alert(L10n.deleteConfirmTitle(), isPresented: $isPresented) {
            Button(L10n.cancel(), role: .cancel) {}
            Button(L10n.deleteSelected(), role: .destructive, action: onConfirm)
        } message: {
            Text(L10n.deleteSelectedConfirmMessage(count))
        }
    }
}
