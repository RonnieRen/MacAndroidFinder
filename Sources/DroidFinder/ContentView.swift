import SwiftUI
import UniformTypeIdentifiers

private struct AppUploadQueuePanelView: View {
    let uploadQueue: [UploadTaskItem]
    let progress: Double
    let onClearFinished: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            ProgressView(value: progress)
                .controlSize(.small)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(uploadQueue) { task in
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
                }
            }
            .frame(maxHeight: 130)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

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

private struct AppFooterBarView: View {
    let isBusy: Bool
    let statusMessage: String

    var body: some View {
        HStack {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            }
            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

}

struct ContentView: View {
    @EnvironmentObject var viewModel: DroidFinderViewModel
    @State private var selectedItemID: String?
    @State private var selectedSidebarPath: String?
    @State private var isDropTargeted = false
    @State private var isUploadQueuePanelVisible = true
    @State private var isWirelessSheetPresented = false
    @State private var pendingDeleteItem: DroidFileItem?
    @State private var isEditMode = false
    @State private var selectedEditItemIDs: Set<String> = []
    @State private var isBulkDeleteConfirmPresented = false

    var body: some View {
        VStack(spacing: 10) {
            TopBarView(
                devices: viewModel.devices,
                selectedDevice: viewModel.selectedDevice,
                onDeviceSelected: { device in
                    viewModel.selectedDevice = device
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

            BreadcrumbBarView(
                breadcrumbs: breadcrumbs,
                canGoParent: viewModel.currentPath != "/",
                onGoParent: {
                    viewModel.goParent()
                    selectedItemID = nil
                },
                onNavigate: { openDirectory($0) }
            )

            Divider()

            ExplorerSplitView(
                directoryRoots: viewModel.directoryTreeStore.directoryTreeRoots,
                selectedSidebarPath: $selectedSidebarPath,
                files: viewModel.files,
                selectedItemID: $selectedItemID,
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
                onToggleEditMode: {
                    isEditMode.toggle()
                    if !isEditMode {
                        selectedEditItemIDs.removeAll()
                    }
                },
                onDeleteSelected: {
                    isBulkDeleteConfirmPresented = true
                },
                onDownloadItem: { viewModel.download($0) },
                onDeleteItem: { pendingDeleteItem = $0 },
                onDropProviders: { providers in handleFileDrop(providers) }
            )

            AppFooterBarView(
                isBusy: viewModel.isBusy || viewModel.uploadQueueStore.isUploading,
                statusMessage: viewModel.statusMessage
            )
        }
        .padding(16)
        .overlay {
            if shouldShowUploadQueuePanel {
                ZStack(alignment: .bottomTrailing) {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isUploadQueuePanelVisible = false
                        }

                    AppUploadQueuePanelView(
                        uploadQueue: viewModel.uploadQueueStore.uploadQueue,
                        progress: viewModel.uploadQueueStore.uploadProgress,
                        onClearFinished: { viewModel.uploadQueueStore.clearFinished() },
                        onClose: { isUploadQueuePanelVisible = false }
                    )
                    .padding(16)
                }
            }
        }
        .onChange(of: viewModel.uploadQueueStore.uploadQueue.isEmpty) { isEmpty in
            if isEmpty {
                isUploadQueuePanelVisible = true
            }
        }
        .sheet(isPresented: $isWirelessSheetPresented) {
            WirelessConnectionSheet(viewModel: viewModel)
                .frame(minWidth: 680, minHeight: 480)
        }
        .alert(L10n.loadingErrorTitle(), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button(L10n.ok(), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? L10n.unknownError())
        }
        .alert(
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
                viewModel.delete(item)
                if selectedItemID == item.id {
                    selectedItemID = nil
                }
                pendingDeleteItem = nil
            }
        } message: { item in
            Text(item.isDirectory ? L10n.deleteConfirmMessageFolder(item.name) : L10n.deleteConfirmMessage(item.name))
        }
        .alert(
            L10n.deleteConfirmTitle(),
            isPresented: $isBulkDeleteConfirmPresented
        ) {
            Button(L10n.cancel(), role: .cancel) {}
            Button(L10n.deleteSelected(), role: .destructive) {
                let selectedItems = viewModel.files.filter { selectedEditItemIDs.contains($0.id) }
                viewModel.delete(items: selectedItems)
                selectedEditItemIDs.removeAll()
                isEditMode = false
                selectedItemID = nil
            }
        } message: {
            Text(L10n.deleteSelectedConfirmMessage(selectedEditItemIDs.count))
        }
    }

    private var selectedFile: DroidFileItem? {
        guard let selectedItemID else { return nil }
        return viewModel.files.first(where: { $0.id == selectedItemID })
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

    private func openDirectory(_ path: String) {
        try? viewModel.loadDirectory(path: path)
        selectedSidebarPath = path
        selectedItemID = nil
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

private struct TopBarView: View {
    let devices: [DroidDevice]
    let selectedDevice: DroidDevice?
    let onDeviceSelected: (DroidDevice?) -> Void
    let onRefresh: () -> Void
    let selectedFile: DroidFileItem?
    let onOpenWireless: () -> Void
    let onDownloadItem: (DroidFileItem) -> Void
    let onDeleteItem: (DroidFileItem) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Picker(L10n.deviceLabel(), selection: Binding(
                get: { selectedDevice?.id ?? "" },
                set: { newID in
                    onDeviceSelected(devices.first(where: { $0.id == newID }))
                }
            )) {
                ForEach(devices) { device in
                    Text(device.displayName).tag(device.id)
                }
            }
            .frame(maxWidth: 320)

            Button(L10n.refreshDevices(), action: onRefresh)

            Spacer()

            Button(L10n.wirelessConnect(), action: onOpenWireless)

            if let selectedFile {
                if !selectedFile.isDirectory {
                    Button(L10n.downloadFile()) {
                        onDownloadItem(selectedFile)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(L10n.deleteFile(), role: .destructive) {
                        onDeleteItem(selectedFile)
                    }
                }
            }
        }
    }
}

private struct WirelessConnectionSheet: View {
    @ObservedObject var viewModel: DroidFinderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pairEndpoint = ""
    @State private var pairCode = ""
    @State private var connectEndpoint = ""
    @State private var manualEndpoint = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.wirelessConnectTitle())
                    .font(.title3.bold())
                Spacer()
                if viewModel.isWirelessBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(L10n.close()) { dismiss() }
            }

            GroupBox(L10n.usbQuickConnect()) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.usbQuickConnectHint())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(viewModel.selectedDevice?.displayName ?? L10n.noUSBDeviceSelected())
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.connectUsingUSB()) {
                            Task { await viewModel.quickConnectSelectedDeviceViaWiFi() }
                        }
                        .disabled(viewModel.selectedDevice == nil || (viewModel.selectedDevice?.id.contains(":") ?? false))
                    }
                }
                .padding(.top, 2)
            }

            GroupBox(L10n.nearbyDevices()) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(L10n.discover()) {
                            Task { await viewModel.discoverWirelessServices() }
                        }
                        Spacer()
                    }

                    if viewModel.wirelessServices.isEmpty {
                        Text(L10n.noNearbyDevices())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        List(viewModel.wirelessServices) { service in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(service.name)
                                    Text("\(service.type) • \(service.endpoint)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(L10n.connect()) {
                                    Task { await viewModel.connectWireless(endpoint: service.endpoint) }
                                }
                                Button(L10n.disconnect()) {
                                    Task { await viewModel.disconnectWireless(endpoint: service.endpoint) }
                                }
                            }
                        }
                        .frame(height: 140)
                    }
                }
                .padding(.top, 2)
            }

            HStack(alignment: .top, spacing: 12) {
                GroupBox(L10n.pairWithCode()) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(L10n.pairEndpoint(), text: $pairEndpoint)
                        TextField(L10n.pairCode(), text: $pairCode)
                        TextField(L10n.connectEndpoint(), text: $connectEndpoint)
                        Button(L10n.pairAndConnect()) {
                            Task {
                                await viewModel.pairAndConnect(
                                    pairEndpoint: pairEndpoint,
                                    pairCode: pairCode,
                                    connectEndpoint: connectEndpoint
                                )
                            }
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 2)
                }

                GroupBox(L10n.manualConnect()) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(L10n.endpoint(), text: $manualEndpoint)
                        HStack {
                            Button(L10n.connect()) {
                                Task { await viewModel.connectWireless(endpoint: manualEndpoint) }
                            }
                            Button(L10n.disconnect()) {
                                Task { await viewModel.disconnectWireless(endpoint: manualEndpoint) }
                            }
                            Button(L10n.disconnectAll()) {
                                Task { await viewModel.disconnectWireless(endpoint: nil) }
                            }
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .task {
            if viewModel.wirelessServices.isEmpty {
                await viewModel.discoverWirelessServices()
            }
        }
    }
}

private struct BreadcrumbBarView: View {
    let breadcrumbs: [(name: String, path: String)]
    let canGoParent: Bool
    let onGoParent: () -> Void
    let onNavigate: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onGoParent()
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(!canGoParent)
            .help(L10n.parentDirectory())

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { idx, crumb in
                        Button(crumb.name) {
                            onNavigate(crumb.path)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(idx == breadcrumbs.count - 1 ? .primary : .secondary)

                        if idx < breadcrumbs.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ExplorerSplitView: View {
    let directoryRoots: [RemoteDirectoryNode]
    @Binding var selectedSidebarPath: String?
    let files: [DroidFileItem]
    @Binding var selectedItemID: String?
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
    
    var body: some View {
        HSplitView {
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
            
            VStack(spacing: 8) {
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
                
                List(selection: $selectedItemID) {
                    ForEach(files) { item in
                        ExplorerFileRowView(
                            item: item,
                            isEditMode: isEditMode,
                            isSelected: selectedEditItemIDs.contains(item.id),
                            onToggleSelection: { toggleSelection(id: item.id) },
                            onTap: { selectedItemID = item.id },
                            onOpenDirectory: { onSelectDirectory(item.fullPath) },
                            onDownloadItem: { onDownloadItem(item) },
                            onDeleteItem: { onDeleteItem(item) }
                        )
                        .tag(item.id)
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
        }
    }

    private func toggleSelection(id: String) {
            if selectedEditItemIDs.contains(id) {
                selectedEditItemIDs.remove(id)
            } else {
                selectedEditItemIDs.insert(id)
            }
        }

}
    
    private struct ExplorerFileRowView: View {
        let item: DroidFileItem
        let isEditMode: Bool
        let isSelected: Bool
        let onToggleSelection: () -> Void
        let onTap: () -> Void
        let onOpenDirectory: () -> Void
        let onDownloadItem: () -> Void
        let onDeleteItem: () -> Void

        var body: some View {
            HStack(spacing: 10) {
                if isEditMode {
                    Button(action: onToggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: iconName(for: item))
                    .frame(width: 18)
                Text(item.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.isDirectory ? L10n.folder() : L10n.file())
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Text(item.sizeDescription)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditMode {
                    onToggleSelection()
                } else {
                    onTap()
                }
            }
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                guard !isEditMode else { return }
                if item.isDirectory {
                    onOpenDirectory()
                } else {
                    onDownloadItem()
                }
            })
            .contextMenu {
                if isEditMode {
                    Button(isSelected ? L10n.done() : L10n.editMode()) {
                        onToggleSelection()
                    }
                } else if item.isDirectory {
                    Button(L10n.openDirectory(), action: onOpenDirectory)
                    Button(L10n.downloadDirectory(), action: onDownloadItem)
                    Button(L10n.deleteFolder(), role: .destructive, action: onDeleteItem)
                } else {
                    Button(L10n.downloadFile(), action: onDownloadItem)
                    Button(L10n.deleteFile(), role: .destructive, action: onDeleteItem)
                }
            }
        }

        private func iconName(for item: DroidFileItem) -> String {
            switch item.type {
            case .directory:
                return "folder"
            case .file:
                return "doc"
            case .symlink:
                return "arrow.trianglehead.branch"
            case .unknown:
                return "questionmark.square"
            }
        }
    }

    private struct UploadQueuePanelView: View {
        let uploadQueue: [UploadTaskItem]
        let progress: Double
        let onClearFinished: () -> Void
        let onClose: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
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
                
                ProgressView(value: progress)
                    .controlSize(.small)
                
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(uploadQueue) { task in
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
                    }
                }
                .frame(maxHeight: 130)
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        
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
    
    private struct FooterBarView: View {
        let isBusy: Bool
        let statusMessage: String
        
        var body: some View {
            HStack {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
    
    private struct DirectoryTreeNodeView: View {
        let node: RemoteDirectoryNode
        let level: Int
        @Binding var selectedPath: String?
        let childProvider: (String) -> [RemoteDirectoryNode]
        let loadingProvider: (String) -> Bool
        let onSelect: (String) -> Void
        let onExpand: (String) -> Void
        
        @State private var isExpanded = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Button {
                        isExpanded.toggle()
                        if isExpanded {
                            onExpand(node.path)
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        selectedPath = node.path
                        onSelect(node.path)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .foregroundStyle(.tint)
                            Text(node.name)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    if loadingProvider(node.path) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    }
                }
                .padding(.leading, CGFloat(level) * 14)
                
                if isExpanded {
                    let children = childProvider(node.path)
                    ForEach(children) { child in
                        DirectoryTreeNodeView(
                            node: child,
                            level: level + 1,
                            selectedPath: $selectedPath,
                            childProvider: childProvider,
                            loadingProvider: loadingProvider,
                            onSelect: onSelect,
                            onExpand: onExpand
                        )
                    }
                }
            }
        }
    }
}
