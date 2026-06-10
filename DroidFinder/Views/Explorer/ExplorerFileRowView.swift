import AppKit
import SwiftUI

// MARK: - ExplorerFileRowView
//
// One row in the explorer's file list. Lays out an optional checkbox (edit
// mode), an icon, and the Name / Type / Modified columns. Owns its drag,
// tap, double-tap, hover-tooltip and context-menu behaviour.

struct ExplorerFileRowView: View {
    let item: DroidFileItem
    let isEditMode: Bool
    let isSelected: Bool
    let isHighlighted: Bool
    @ObservedObject var columnWidths: ColumnWidths
    let onToggleSelection: () -> Void
    let onRowClick: () -> Void
    let onOpenDirectory: () -> Void
    let onDownloadItem: () -> Void
    let onDeleteItem: () -> Void
    let onOpenInApp: () -> Void
    let dragProvidersForThisDrag: () -> [NSPasteboardWriting]

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        rowContent
            .frame(height: 22)
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }
            .simultaneousGesture(TapGesture(count: 2).onEnded { handleDoubleTap() })
            .contextMenu { contextMenuContent }
            // We replace SwiftUI's `.onDrag` with an AppKit overlay so that
            // multi-selection drags can carry every selected NSItemProvider
            // (SwiftUI's `.onDrag` only ever exports one).
            .background(
                MultiItemDragOverlay(providersProvider: dragProvidersForThisDrag)
            )
    }

    // MARK: - Layout

    private var rowContent: some View {
        // Reserve fixed leading width for the checkbox + icon so the
        // percentage-based columns stay aligned across rows regardless of
        // edit mode.
        GeometryReader { geo in
            let leading: CGFloat = isEditMode ? (24 + 18 + 30) : (18 + 20)
            let usable = max(geo.size.width - leading, 0)
            let nameW = usable * columnWidths.nameFrac
            let typeW = usable * columnWidths.typeFrac
            let dateW = usable * columnWidths.dateFrac

            HStack(spacing: 10) {
                if isEditMode {
                    Button(action: onToggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24)
                }

                Image(systemName: iconName(for: item))
                    .frame(width: 18)
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: nameW, alignment: .leading)
                    .contentShape(Rectangle())
                    .finderHoverTooltip(item.name, enabled: isSelected || isHighlighted)
                Text(item.isDirectory ? L10n.folder() : L10n.file())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: typeW, alignment: .leading)
                if let date = item.modifiedDate {
                    Text(Self.dateFormatter.string(from: date))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: dateW, alignment: .trailing)
                } else {
                    Text(item.sizeDescription)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: dateW, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Gestures

    private func handleTap() {
        if isEditMode {
            onToggleSelection()
        } else {
            onRowClick()
        }
    }

    private func handleDoubleTap() {
        guard !isEditMode else { return }
        if item.isDirectory {
            onOpenDirectory()
        } else {
            onOpenInApp()
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if isEditMode {
            Button(isSelected ? L10n.done() : L10n.editMode()) {
                onToggleSelection()
            }
        } else if item.isDirectory {
            Button(L10n.openDirectory(), action: onOpenDirectory)
            Button(L10n.downloadDirectory(), action: onDownloadItem)
            Button(L10n.deleteFolder(), role: .destructive, action: onDeleteItem)
        } else {
            Button(L10n.openFile(), action: onOpenInApp)
            Button(L10n.downloadFile(), action: onDownloadItem)
            Button(L10n.deleteFile(), role: .destructive, action: onDeleteItem)
        }
    }

    // MARK: - Helpers

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
