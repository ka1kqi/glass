import Foundation
import Combine

/// The selected glass design, persisted across launches.
@MainActor
final class DesignModel: ObservableObject {
    private static let defaultsKey = "GlassDesign"

    @Published var designID: String {
        didSet { UserDefaults.standard.set(designID, forKey: Self.defaultsKey) }
    }

    var current: any GlassDesign { DesignCatalog.design(withID: designID) }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? ""
        // Round-trip through the catalog normalizes unknown ids.
        designID = DesignCatalog.design(withID: saved).id
    }
}
