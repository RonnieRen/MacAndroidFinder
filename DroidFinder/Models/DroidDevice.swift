import Foundation

// MARK: - DroidDevice

struct DroidDevice: Identifiable, Hashable {
    let id: String
    let model: String
    let transportState: String

    var displayName: String {
        model.isEmpty ? id : "\(model) (\(id))"
    }
}
