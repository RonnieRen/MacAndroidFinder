import Foundation
import SwiftUI

// MARK: - ColumnWidths
//
// Observable state for the explorer column widths (Name / Type / Modified),
// expressed as fractions of the available row width. Persisted to
// UserDefaults so the user's sizing survives across launches.

@MainActor
final class ColumnWidths: ObservableObject {
    @Published var nameFrac: CGFloat
    @Published var typeFrac: CGFloat
    @Published var dateFrac: CGFloat

    private static let key = "DroidFinder.ColumnWidths.v1"
    private static let minFrac: CGFloat = 0.08

    init() {
        if let dict = UserDefaults.standard.dictionary(forKey: Self.key),
           let name = dict["name"] as? Double,
           let type = dict["type"] as? Double,
           let date = dict["date"] as? Double {
            self.nameFrac = CGFloat(name)
            self.typeFrac = CGFloat(type)
            self.dateFrac = CGFloat(date)
        } else {
            self.nameFrac = 0.60
            self.typeFrac = 0.15
            self.dateFrac = 0.25
        }
    }

    /// Adjust the split between `name` and `type` (drag the divider between
    /// columns 1 and 2). `delta` is in fractional units already (drag pixels
    /// divided by total usable width).
    func dragNameTypeDivider(deltaFrac: CGFloat) {
        let proposedName = nameFrac + deltaFrac
        let proposedType = typeFrac - deltaFrac
        guard proposedName >= Self.minFrac, proposedType >= Self.minFrac else { return }
        nameFrac = proposedName
        typeFrac = proposedType
        persist()
    }

    /// Drag the divider between columns 2 (type) and 3 (date).
    func dragTypeDateDivider(deltaFrac: CGFloat) {
        let proposedType = typeFrac + deltaFrac
        let proposedDate = dateFrac - deltaFrac
        guard proposedType >= Self.minFrac, proposedDate >= Self.minFrac else { return }
        typeFrac = proposedType
        dateFrac = proposedDate
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(
            ["name": Double(nameFrac), "type": Double(typeFrac), "date": Double(dateFrac)],
            forKey: Self.key
        )
    }
}
