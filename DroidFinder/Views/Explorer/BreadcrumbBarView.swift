import SwiftUI

// MARK: - BreadcrumbBarView
//
// Up-arrow + horizontally scrollable path crumbs above the file list.

struct BreadcrumbBarView: View {
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
