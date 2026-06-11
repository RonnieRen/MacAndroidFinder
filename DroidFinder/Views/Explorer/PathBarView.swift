import SwiftUI

// MARK: - PathBarView
//
// 44px path bar: back/forward arrows + clickable breadcrumbs.

struct PathBarView: View {
    let breadcrumbs: [(name: String, path: String)]
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onNavigate: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                navArrow(systemImage: "chevron.left", enabled: canGoBack, action: onBack)
                navArrow(systemImage: "chevron.right", enabled: canGoForward, action: onForward)
            }
            .padding(.trailing, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(breadcrumbs.enumerated()), id: \.element.path) { index, crumb in
                        let isLast = index == breadcrumbs.count - 1
                        Button {
                            if !isLast { onNavigate(crumb.path) }
                        } label: {
                            Text(crumb.name)
                                .font(.system(size: 13, weight: isLast ? .semibold : .regular))
                                .foregroundStyle(isLast ? DFTheme.ink : DFTheme.ink2)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6).fill(Color.clear)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)

                        if !isLast {
                            Text("›")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 0xC9 / 255, green: 0xC9 / 255, blue: 0xD0 / 255))
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: DFTheme.pathbarHeight)
        .overlay(alignment: .bottom) {
            DFTheme.lineSoft.frame(height: 1)
        }
    }

    private func navArrow(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(enabled
                                 ? Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x5E / 255)
                                 : Color(red: 0xC9 / 255, green: 0xC9 / 255, blue: 0xD0 / 255))
        }
        .buttonStyle(DFIconButtonStyle(size: CGSize(width: 28, height: 28)))
        .disabled(!enabled)
    }
}
