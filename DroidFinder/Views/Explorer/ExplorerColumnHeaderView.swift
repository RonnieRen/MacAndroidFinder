import SwiftUI

// MARK: - ExplorerColumnHeaderView
//
// Header row above the file list — Name / Type / Modified — with a draggable
// divider between adjacent columns so the user can resize them.

struct ExplorerColumnHeaderView: View {
    let isEditMode: Bool
    @ObservedObject var widths: ColumnWidths

    var body: some View {
        GeometryReader { geo in
            // Keep this in sync with the leading layout used inside
            // ExplorerFileRowView so header columns line up over row columns.
            let leading: CGFloat = isEditMode ? (24 + 18 + 30) : (18 + 20)
            let usable = max(geo.size.width - leading, 0)
            let nameW = usable * widths.nameFrac
            let typeW = usable * widths.typeFrac
            let dateW = usable * widths.dateFrac

            HStack(spacing: 10) {
                if isEditMode {
                    Color.clear.frame(width: 24)
                }
                Color.clear.frame(width: 18)

                ZStack(alignment: .trailing) {
                    Text("Name")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: nameW, alignment: .leading)
                    ColumnDividerHandle { delta in
                        guard usable > 0 else { return }
                        widths.dragNameTypeDivider(deltaFrac: delta / usable)
                    }
                }
                ZStack(alignment: .trailing) {
                    Text("Type")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: typeW, alignment: .leading)
                    ColumnDividerHandle { delta in
                        guard usable > 0 else { return }
                        widths.dragTypeDateDivider(deltaFrac: delta / usable)
                    }
                }
                Text("Modified")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: dateW, alignment: .trailing)
            }
        }
        .frame(height: 18)
        .padding(.horizontal, 8) // match List default insets visually
    }
}
