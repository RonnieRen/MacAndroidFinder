import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: DroidFinderViewModel
    @State private var selectedItemID: String?
    @State private var selectedSidebarPath: String?
    @State private var isDropTargeted = false
    @State private var isUploadQueuePanelVisible = true

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
                onGoParent: {
                    viewModel.goParent()
                    selectedItemID = nil
                },
                canGoParent: viewModel.currentPath != "/",
                selectedFile: selectedFile,
                onUpload: {
                    isUploadQueuePanelVisible = true
                    viewModel.chooseAndUploadFiles(to: dropTargetDirectoryPath)
                },
                onOpenDirectory: { openDirectory($0) },
                onDownloadFile: { viewModel.download($0) }
            )

            BreadcrumbBarView(
                breadcrumbs: breadcrumbs,
                onNavigate: { openDirectory($0) }
            )

            Divider()

            ExplorerSplitView(
                directoryRoots: viewModel.directoryTreeStore.directoryTreeRoots,
                selectedSidebarPath: $selectedSidebarPath,
                files: viewModel.files,
                selectedItemID: $selectedItemID,
                isDropTargeted: $isDropTargeted,
                dropTargetDirectoryPath: dropTargetDirectoryPath,
                onSelectDirectory: { openDirectory($0) },
                childrenForDirectory: { viewModel.directoryTreeStore.childrenForDirectory(path: $0) },
                isDirectoryLoading: { viewModel.directoryTreeStore.isDirectoryLoading(path: $0) },
                onExpandDirectory: { viewModel.directoryTreeStore.ensureLoaded(path: $0) },
                onDownloadFile: { viewModel.download($0) },
                onDropProviders: { providers in handleFileDrop(providers) }
            )

            FooterBarView(
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
        .onChange(of: viewModel.uploadQueueStore.uploadQueue.isEmpty) { isEmpty in
            if isEmpty {
                isUploadQueuePanelVisible = true
            }
        }
        .alert("错误", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
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
}

private struct TopBarView: View {
    let devices: [DroidDevice]
    let selectedDevice: DroidDevice?
    let onDeviceSelected: (DroidDevice?) -> Void
    let onRefresh: () -> Void
    let onGoParent: () -> Void
    let canGoParent: Bool
    let selectedFile: DroidFileItem?
    let onUpload: () -> Void
    let onOpenDirectory: (String) -> Void
    let onDownloadFile: (DroidFileItem) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Picker("设备", selection: Binding(
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

            Button("刷新设备", action: onRefresh)
            Button("上一级", action: onGoParent)
                .disabled(!canGoParent)

            Spacer()

            Button("上传文件", action: onUpload)

            if let selectedFile {
                if selectedFile.isDirectory {
                    Button("进入目录") {
                        onOpenDirectory(selectedFile.fullPath)
                    }
                } else {
                    Button("下载文件") {
                        onDownloadFile(selectedFile)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

private struct BreadcrumbBarView: View {
    let breadcrumbs: [(name: String, path: String)]
    let onNavigate: (String) -> Void

    var body: some View {
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

private struct ExplorerSplitView: View {
    let directoryRoots: [RemoteDirectoryNode]
    @Binding var selectedSidebarPath: String?
    let files: [DroidFileItem]
    @Binding var selectedItemID: String?
    @Binding var isDropTargeted: Bool
    let dropTargetDirectoryPath: String
    let onSelectDirectory: (String) -> Void
    let childrenForDirectory: (String) -> [RemoteDirectoryNode]
    let isDirectoryLoading: (String) -> Bool
    let onExpandDirectory: (String) -> Void
    let onDownloadFile: (DroidFileItem) -> Void
    let onDropProviders: ([NSItemProvider]) -> Bool

    var body: some View {
        HSplitView {
            List {
                Section("目录树") {
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

            List(selection: $selectedItemID) {
                ForEach(files) { item in
                    HStack(spacing: 10) {
                        Image(systemName: iconName(for: item))
                            .frame(width: 18)
                        Text(item.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.isDirectory ? "文件夹" : "文件")
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(item.sizeDescription)
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItemID = item.id
                    }
                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                        if item.isDirectory {
                            onSelectDirectory(item.fullPath)
                        } else {
                            onDownloadFile(item)
                        }
                    })
                    .contextMenu {
                        if item.isDirectory {
                            Button("打开") { onSelectDirectory(item.fullPath) }
                        } else {
                            Button("下载") { onDownloadFile(item) }
                        }
                    }
                    .tag(item.id)
                }
            }
            .overlay {
                if files.isEmpty {
                    Text("当前目录为空")
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(alignment: .topLeading) {
                if isDropTargeted {
                    Text("松开即可上传到：\(dropTargetDirectoryPath)")
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
                Text("上传队列")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("关闭")
                Text("\(completedCount)/\(uploadQueue.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("清理已完成", action: onClearFinished)
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
                            Text(task.status.rawValue)
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
