import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView
//
// Window assembly for the 2026-06 redesign:
//   toolbar (60) / sidebar (224) + pathbar (44) + table / preview (292)
//   / status bar (30), plus the connect empty state, upload queue overlay,
//   wireless sheet and alerts.

struct ContentView: View {
    @EnvironmentObject var viewModel: DroidFinderViewModel

    @State private var fileSelection: Set<String> = []
    @State private var isDropTargeted = false
    @State private var isTransferPopoverVisible = true
    @State private var isWirelessSheetPresented = false
    @State private var pendingDeleteItem: DroidFileItem?
    @State private var isBulkDeleteConfirmPresented = false
    @AppStorage("explorerViewMode") private var viewModeRaw = ExplorerViewMode.list.rawValue

    var body: some View {
        VStack(spacing: 0) {
            MainToolbarView(
                devices: viewModel.devices,
                selectedDevice: viewModel.selectedDevice,
                deviceDetail: viewModel.deviceDetail,
                isOffline: viewModel.selectedDevice == nil,
                searchText: $viewModel.searchText,
                viewMode: viewModeBinding,
                canSaveToMac: !selectedItems.isEmpty,
                transferActiveCount: viewModel.transferQueueStore.tasks.isEmpty
                    ? nil
                    : viewModel.transferQueueStore.activeCount,
                onSelectDevice: { selectDevice($0) },
                onOpenWireless: { isWirelessSheetPresented = true },
                onRefresh: { Task { await viewModel.refreshDevices() } },
                onSendToPhone: {
                    isTransferPopoverVisible = true
                    viewModel.chooseAndUploadFiles(to: dropTargetDirectoryPath)
                },
                onSaveToMac: { saveSelectionToMac() },
                onToggleTransfers: { isTransferPopoverVisible.toggle() }
            )

            if viewModel.selectedDevice == nil {
                ConnectEmptyView(
                    qrController: viewModel.qrPairingController,
                    onOpenAdvanced: { isWirelessSheetPresented = true }
                )
            } else {
                explorerBody
            }

            StatusBarView(
                itemCount: viewModel.displayedFiles.count,
                selectionCount: selectedItems.count,
                selectionBytes: selectionBytes,
                deviceName: viewModel.selectedDevice?.displayName,
                freeBytes: viewModel.deviceDetail?.storageFreeBytes,
                isBusy: viewModel.isBusy || viewModel.transferQueueStore.isTransferring,
                statusMessage: viewModel.statusMessage,
                transferSummary: transferSummary
            )
        }
        .ignoresSafeArea()
        .background(DFTheme.winBG)
        .overlay(alignment: .topTrailing) { transferPopoverOverlay }
        .onChange(of: viewModel.transferQueueStore.tasks.isEmpty) { isEmpty in
            if isEmpty { isTransferPopoverVisible = true }
        }
        .onChange(of: fileSelection) { newSelection in
            updatePreview(for: newSelection)
        }
        .sheet(isPresented: $isWirelessSheetPresented) {
            WirelessConnectionSheet(viewModel: viewModel)
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
        .alert(L10n.deleteConfirmTitle(), isPresented: $isBulkDeleteConfirmPresented) {
            Button(L10n.cancel(), role: .cancel) {}
            Button(L10n.deleteSelected(), role: .destructive) {
                viewModel.delete(items: selectedItems)
                fileSelection = []
            }
        } message: {
            Text(L10n.deleteSelectedConfirmMessage(selectedItems.count))
        }
    }

    // MARK: - Explorer body

    private var explorerBody: some View {
        HStack(spacing: 0) {
            SidebarView(
                treeStore: viewModel.directoryTreeStore,
                currentPath: viewModel.currentPath,
                deviceDetail: viewModel.deviceDetail,
                onNavigate: { navigate(to: $0) },
                onOpenQuickAccess: { openQuickAccess($0) }
            )

            VStack(spacing: 0) {
                PathBarView(
                    breadcrumbs: breadcrumbs,
                    canGoBack: viewModel.canGoBack,
                    canGoForward: viewModel.canGoForward,
                    onBack: { viewModel.goBack(); fileSelection = [] },
                    onForward: { viewModel.goForward(); fileSelection = [] },
                    onNavigate: { navigate(to: $0) }
                )

                if viewModeBinding.wrappedValue == .grid {
                    FileGridView(
                        files: viewModel.displayedFiles,
                        isSearching: !viewModel.searchText.isEmpty,
                        fileSelection: $fileSelection,
                        isDropTargeted: $isDropTargeted,
                        dropTargetDirectoryPath: dropTargetDirectoryPath,
                        thumbnailStore: viewModel.thumbnailStore,
                        deviceSerial: viewModel.selectedDevice?.id,
                        onOpenDirectory: { navigate(to: $0) },
                        onOpenInApp: { viewModel.openInApp($0) },
                        onDownloadItem: { viewModel.download($0) },
                        onDeleteItem: { pendingDeleteItem = $0 },
                        onDownloadSelection: { saveSelectionToMac() },
                        onDeleteSelection: { isBulkDeleteConfirmPresented = true },
                        onDropProviders: { handleFileDrop($0) },
                        dragItemProviders: { viewModel.makeFilePromiseProviders(for: $0) }
                    )
                } else {
                    FileTableView(
                        files: viewModel.displayedFiles,
                        isSearching: !viewModel.searchText.isEmpty,
                        fileSelection: $fileSelection,
                        isDropTargeted: $isDropTargeted,
                        dropTargetDirectoryPath: dropTargetDirectoryPath,
                        thumbnailStore: viewModel.thumbnailStore,
                        deviceSerial: viewModel.selectedDevice?.id,
                        onOpenDirectory: { navigate(to: $0) },
                        onOpenInApp: { viewModel.openInApp($0) },
                        onDownloadItem: { viewModel.download($0) },
                        onDeleteItem: { pendingDeleteItem = $0 },
                        onDownloadSelection: { saveSelectionToMac() },
                        onDeleteSelection: { isBulkDeleteConfirmPresented = true },
                        onDropProviders: { handleFileDrop($0) },
                        dragItemProviders: { viewModel.makeFilePromiseProviders(for: $0) }
                    )
                }
            }

            if let item = selectedFile {
                PreviewPanelView(
                    previewService: viewModel.imagePreviewService,
                    item: item,
                    onSaveToMac: { viewModel.download(item) },
                    onShare: { anchor in viewModel.share(item, from: anchor) },
                    onOpen: {
                        if item.isDirectory {
                            navigate(to: item.fullPath)
                        } else {
                            viewModel.openInApp(item)
                        }
                    },
                    onDelete: { pendingDeleteItem = item }
                )
            }
        }
    }

    @ViewBuilder
    private var transferPopoverOverlay: some View {
        if isTransferPopoverVisible && !viewModel.transferQueueStore.tasks.isEmpty {
            TransferPopoverView(
                store: viewModel.transferQueueStore,
                onClose: { isTransferPopoverVisible = false }
            )
            .padding(.top, DFTheme.toolbarHeight + 6)
            .padding(.trailing, 14)
        }
    }

    private var transferSummary: String? {
        let store = viewModel.transferQueueStore
        guard store.activeCount > 0 else { return nil }
        var summary = L10n.transferringSummary(store.activeCount)
        if let speed = store.currentSpeed {
            summary += " · " + DeviceDetail.formatBytes(Int64(speed)) + "/s"
        }
        return summary
    }

    // MARK: - Derived state

    private var viewModeBinding: Binding<ExplorerViewMode> {
        Binding(
            get: { ExplorerViewMode(rawValue: viewModeRaw) ?? .list },
            set: { viewModeRaw = $0.rawValue }
        )
    }

    private var selectedItems: [DroidFileItem] {
        viewModel.files.filter { fileSelection.contains($0.id) }
    }

    private var selectedFile: DroidFileItem? {
        fileSelection.count == 1 ? selectedItems.first : nil
    }

    private var selectionBytes: Int64? {
        let total = selectedItems.compactMap { Int64($0.sizeDescription) }.reduce(0, +)
        return total > 0 ? total : nil
    }

    private var breadcrumbs: [(name: String, path: String)] {
        if viewModel.currentPath == "/" {
            return [("/", "/")]
        }
        let components = viewModel.currentPath.split(separator: "/").map(String.init)
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

    // MARK: - Actions

    private func navigate(to path: String) {
        viewModel.navigate(to: path)
        fileSelection = []
    }

    private func openQuickAccess(_ item: QuickAccessItem) {
        for path in item.candidatePaths {
            if viewModel.navigate(to: path, quiet: true) {
                fileSelection = []
                return
            }
        }
        // None of the candidates exist on this device.
        viewModel.statusMessage = L10n.quickAccessNotFound(item.title)
    }

    private func selectDevice(_ device: DroidDevice) {
        viewModel.selectedDevice = device
        fileSelection = []
        viewModel.imagePreviewService.reset()
        viewModel.thumbnailStore.reset()
        viewModel.refreshDeviceDetail()
        try? viewModel.loadDirectory(path: viewModel.currentPath)
    }

    private func saveSelectionToMac() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        if items.count == 1 {
            viewModel.download(items[0])
        } else {
            viewModel.download(items: items)
        }
    }

    private func updatePreview(for selection: Set<String>) {
        if let id = selection.count == 1 ? selection.first : nil,
           let item = viewModel.files.first(where: { $0.id == id }),
           let serial = viewModel.selectedDevice?.id {
            viewModel.imagePreviewService.request(item: item, deviceSerial: serial)
        } else {
            viewModel.imagePreviewService.reset()
        }
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
                    isTransferPopoverVisible = true
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
