import SwiftUI

// MARK: - DFTheme
//
// Design tokens from the 2026-06 redesign handoff (DroidFinder-handoff.html).
// Mirrors the :root CSS variables — keep names aligned with the handoff so
// future screens can be transcribed 1:1.

enum DFTheme {
    // MARK: Colors

    /// #3D63DD — primary accent.
    static let accent = Color(red: 0x3D / 255, green: 0x63 / 255, blue: 0xDD / 255)
    /// #EBF0FE — selected row background.
    static let accentSoft = Color(red: 0xEB / 255, green: 0xF0 / 255, blue: 0xFE / 255)
    /// #DEE7FC — selected sidebar item background.
    static let accentSoft2 = Color(red: 0xDE / 255, green: 0xE7 / 255, blue: 0xFC / 255)
    /// #1C1C21 — primary text.
    static let ink = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x21 / 255)
    /// #6E6E78 — secondary text.
    static let ink2 = Color(red: 0x6E / 255, green: 0x6E / 255, blue: 0x78 / 255)
    /// #9B9BA4 — tertiary text / placeholders.
    static let ink3 = Color(red: 0x9B / 255, green: 0x9B / 255, blue: 0xA4 / 255)
    /// #E8E8EC — standard hairline.
    static let line = Color(red: 0xE8 / 255, green: 0xE8 / 255, blue: 0xEC / 255)
    /// #F0F0F3 — softer hairline (table separators).
    static let lineSoft = Color(red: 0xF0 / 255, green: 0xF0 / 255, blue: 0xF3 / 255)
    /// #FFFFFF — window background.
    static let winBG = Color.white
    /// #F7F7F9 — sidebar background.
    static let sidebarBG = Color(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF9 / 255)
    /// #FBFBFC — preview panel background.
    static let previewBG = Color(red: 0xFB / 255, green: 0xFB / 255, blue: 0xFC / 255)
    /// #FAFAFB — toolbar / status bar background.
    static let barBG = Color(red: 0xFA / 255, green: 0xFA / 255, blue: 0xFB / 255)
    /// #F2F2F5 — search field / segmented control track.
    static let fieldBG = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF5 / 255)
    /// #F7F7F9 — row hover.
    static let hoverBG = Color(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF9 / 255)
    /// #34B96F — success / upload direction.
    static let green = Color(red: 0x34 / 255, green: 0xB9 / 255, blue: 0x6F / 255)
    /// #E5484D — destructive.
    static let red = Color(red: 0xE5 / 255, green: 0x48 / 255, blue: 0x4D / 255)
    /// #27324F — selected row primary text.
    static let selectedInk = Color(red: 0x27 / 255, green: 0x32 / 255, blue: 0x4F / 255)
    /// #5A6A94 — selected row secondary text.
    static let selectedInk2 = Color(red: 0x5A / 255, green: 0x6A / 255, blue: 0x94 / 255)

    // MARK: Metrics

    static let toolbarHeight: CGFloat = 60
    static let sidebarWidth: CGFloat = 224
    static let previewWidth: CGFloat = 292
    static let pathbarHeight: CGFloat = 44
    static let tableHeaderHeight: CGFloat = 34
    static let rowHeight: CGFloat = 46
    static let statusBarHeight: CGFloat = 30
    static let radius: CGFloat = 12
    static let controlRadius: CGFloat = 8
}

// MARK: - Shared control styles

/// "btn" from the handoff: 34px bordered chip, optional primary (accent) fill.
struct DFButtonStyle: ButtonStyle {
    var isPrimary = false
    var height: CGFloat = 34

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isPrimary ? Color.white : DFTheme.ink)
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isPrimary ? DFTheme.accent : DFTheme.winBG)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(isPrimary ? DFTheme.accent : DFTheme.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}

/// "icon-btn": 32–34px square hover-highlight icon button.
struct DFIconButtonStyle: ButtonStyle {
    var size = CGSize(width: 34, height: 32)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x5E / 255))
            .frame(width: size.width, height: size.height)
            .background(
                RoundedRectangle(cornerRadius: DFTheme.controlRadius)
                    .fill(configuration.isPressed ? DFTheme.fieldBG : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: DFTheme.controlRadius))
    }
}
