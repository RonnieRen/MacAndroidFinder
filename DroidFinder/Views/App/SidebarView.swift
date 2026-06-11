import SwiftUI

// MARK: - SidebarView
//
// 224px sidebar from the redesign: "Quick Access" bookmarks, the lazy device
// directory tree, and a storage gauge pinned to the bottom.

struct QuickAccessItem: Identifiable {
    let title: String
    let systemImage: String
    /// Candidate remote paths, first one that loads wins.
    let candidatePaths: [String]

    var id: String { title }

    static func defaults() -> [QuickAccessItem] {
        [
            QuickAccessItem(
                title: L10n.qaScreenshots(),
                systemImage: "iphone",
                candidatePaths: ["/sdcard/DCIM/Screenshots", "/sdcard/Pictures/Screenshots"]
            ),
            QuickAccessItem(
                title: L10n.qaCamera(),
                systemImage: "camera",
                candidatePaths: ["/sdcard/DCIM/Camera"]
            ),
            QuickAccessItem(
                title: L10n.qaDownloads(),
                systemImage: "arrow.down.to.line",
                candidatePaths: ["/sdcard/Download", "/sdcard/Downloads"]
            ),
            QuickAccessItem(
                title: L10n.qaWeChat(),
                systemImage: "message",
                candidatePaths: [
                    "/sdcard/Download/WeiXin",
                    "/sdcard/Pictures/WeiXin",
                    "/sdcard/tencent/MicroMsg/Download",
                    "/sdcard/Tencent/MicroMsg/Download"
                ]
            )
        ]
    }
}

struct SidebarView: View {
    @ObservedObject var treeStore: DirectoryTreeStore
    let currentPath: String
    let deviceDetail: DeviceDetail?
    let onNavigate: (String) -> Void
    let onOpenQuickAccess: (QuickAccessItem) -> Void

    @State private var expandedPaths: Set<String> = ["/sdcard", "/sdcard/DCIM"]
    private let quickAccess = QuickAccessItem.defaults()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionLabel(L10n.quickAccess())
                    ForEach(quickAccess) { item in
                        quickAccessRow(item)
                    }

                    Spacer().frame(height: 16)

                    sectionLabel(L10n.deviceDirectory())
                    ForEach(treeStore.directoryTreeRoots) { root in
                        treeRows(node: root, level: 1)
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 10)
            }

            storageGauge
        }
        .frame(width: DFTheme.sidebarWidth)
        .background(DFTheme.sidebarBG)
        .overlay(alignment: .trailing) {
            DFTheme.line.frame(width: 1)
        }
    }

    // MARK: - Sections

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DFTheme.ink3)
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 6)
    }

    private func quickAccessRow(_ item: QuickAccessItem) -> some View {
        let isActive = item.candidatePaths.contains(currentPath)
        return Button {
            onOpenQuickAccess(item)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? DFTheme.accent : Color(red: 0x8E / 255, green: 0x8E / 255, blue: 0x98 / 255))
                    .frame(width: 16)
                Text(item.title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? DFTheme.accent : Color(red: 0x3A / 255, green: 0x3A / 255, blue: 0x42 / 255))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: DFTheme.controlRadius)
                    .fill(isActive ? DFTheme.accentSoft2 : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: DFTheme.controlRadius))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Directory tree

    @ViewBuilder
    private func treeRows(node: RemoteDirectoryNode, level: Int) -> some View {
        treeRow(node: node, level: level)
        if expandedPaths.contains(node.path) {
            ForEach(treeStore.childrenForDirectory(path: node.path)) { child in
                AnyView(treeRows(node: child, level: min(level + 1, 3)))
            }
        }
    }

    private func treeRow(node: RemoteDirectoryNode, level: Int) -> some View {
        let isActive = node.path == currentPath
        let isExpanded = expandedPaths.contains(node.path)

        return HStack(spacing: 9) {
            Button {
                toggleExpansion(node)
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(DFTheme.ink3)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundStyle(isActive ? DFTheme.accent : Color(red: 0x8E / 255, green: 0x8E / 255, blue: 0x98 / 255))

            Text(node.name)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? DFTheme.accent : Color(red: 0x3A / 255, green: 0x3A / 255, blue: 0x42 / 255))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(10 + (level - 1) * 16))
        .padding(.trailing, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: DFTheme.controlRadius)
                .fill(isActive ? DFTheme.accentSoft2 : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: DFTheme.controlRadius))
        .onTapGesture {
            onNavigate(node.path)
            if !isExpanded {
                toggleExpansion(node)
            }
        }
    }

    private func toggleExpansion(_ node: RemoteDirectoryNode) {
        if expandedPaths.contains(node.path) {
            expandedPaths.remove(node.path)
        } else {
            expandedPaths.insert(node.path)
            treeStore.ensureLoaded(path: node.path)
        }
    }

    // MARK: - Storage gauge

    @ViewBuilder
    private var storageGauge: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(L10n.deviceStorage())
                Spacer()
                if let used = deviceDetail?.storageUsedBytes, let total = deviceDetail?.storageTotalBytes {
                    Text("\(DeviceDetail.formatBytes(used)) / \(DeviceDetail.formatBytes(total))")
                } else {
                    Text("—")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(DFTheme.ink2)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 0xE4 / 255, green: 0xE4 / 255, blue: 0xE9 / 255))
                    Capsule()
                        .fill(DFTheme.accent)
                        .frame(width: geo.size.width * (deviceDetail?.storageFraction ?? 0))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            DFTheme.line.frame(height: 1).padding(.horizontal, 10)
        }
    }
}
