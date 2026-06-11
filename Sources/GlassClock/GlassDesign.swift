import SwiftUI

/// One ambient look for the glass. A design contributes the layer
/// rendered between the blur material and the clock digits; the rim and
/// glint overlays are shared by all designs.
@MainActor
protocol GlassDesign {
    /// Stable identifier persisted in UserDefaults — never change one.
    var id: String { get }
    /// Menu title.
    var name: String { get }
    /// The ambient layer; built fresh whenever the design is applied.
    func ambientLayer(paused: Bool) -> AnyView
}

/// Today's look, exactly: no ambient layer at all.
struct StillGlassDesign: GlassDesign {
    let id = "still-glass"
    let name = "Still Glass"
    func ambientLayer(paused: Bool) -> AnyView { AnyView(EmptyView()) }
}

/// Living glass: time-of-day aurora plus film grain.
struct SolarAuroraDesign: GlassDesign {
    let id = "solar-aurora"
    let name = "Solar Aurora"
    func ambientLayer(paused: Bool) -> AnyView {
        AnyView(SolarAuroraLayer(paused: paused).overlay(GrainOverlay()))
    }
}

/// Every available design, in menu order. The first entry is the default
/// and the fallback for unknown persisted ids.
@MainActor
enum DesignCatalog {
    static let all: [any GlassDesign] = [
        StillGlassDesign(),
        SolarAuroraDesign(),
    ]

    static func design(withID id: String) -> any GlassDesign {
        all.first { $0.id == id } ?? all[0]
    }
}
