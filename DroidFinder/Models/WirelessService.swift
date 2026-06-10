import Foundation

// MARK: - WirelessService

struct WirelessService: Identifiable, Hashable {
    let name: String
    let type: String
    let endpoint: String

    var id: String { "\(name)|\(type)|\(endpoint)" }
}
