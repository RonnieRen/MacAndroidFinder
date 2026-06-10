import SwiftUI

// MARK: - DirectoryTreeNodeView
//
// Recursive sidebar entry: chevron + folder name; expanding loads children
// lazily via the provided callbacks.

struct DirectoryTreeNodeView: View {
    let node: RemoteDirectoryNode
    let level: Int
    @Binding var selectedPath: String?
    let childProvider: (String) -> [RemoteDirectoryNode]
    let loadingProvider: (String) -> Bool
    let onSelect: (String) -> Void
    let onExpand: (String) -> Void

    @State private var isExpanded: Bool

    init(
        node: RemoteDirectoryNode,
        level: Int,
        selectedPath: Binding<String?>,
        childProvider: @escaping (String) -> [RemoteDirectoryNode],
        loadingProvider: @escaping (String) -> Bool,
        onSelect: @escaping (String) -> Void,
        onExpand: @escaping (String) -> Void
    ) {
        self.node = node
        self.level = level
        _selectedPath = selectedPath
        self.childProvider = childProvider
        self.loadingProvider = loadingProvider
        self.onSelect = onSelect
        self.onExpand = onExpand
        _isExpanded = State(initialValue: node.autoExpand)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                disclosureButton
                folderButton
                Spacer()
                if loadingProvider(node.path) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
            }
            .padding(.leading, CGFloat(level) * 14)

            if isExpanded {
                ForEach(childProvider(node.path)) { child in
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
        .task {
            if isExpanded {
                onExpand(node.path)
            }
        }
    }

    private var disclosureButton: some View {
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
    }

    private var folderButton: some View {
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
    }
}
