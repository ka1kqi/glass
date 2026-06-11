import Foundation
import Combine

/// Whether the reactive lighting overlays (cursor-lit rim arc and the
/// minute glint) are enabled; persisted, on by default. The hairline rim
/// itself is part of the glass, not an effect, and always stays.
@MainActor
final class LightingModel: ObservableObject {
    private static let defaultsKey = "GlassLightingEffects"

    @Published var isOn: Bool {
        didSet { UserDefaults.standard.set(isOn, forKey: Self.defaultsKey) }
    }

    init() {
        isOn = UserDefaults.standard.object(forKey: Self.defaultsKey) as? Bool ?? true
    }
}
