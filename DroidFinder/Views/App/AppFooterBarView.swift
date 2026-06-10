import SwiftUI

// MARK: - AppFooterBarView
//
// Status bar at the bottom of the main window. Shows a spinner when the app is
// busy and a single-line status message.

struct AppFooterBarView: View {
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
