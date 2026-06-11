import SwiftUI
import GlassClockCore

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
    /// Color of the cursor-reactive specular arc on the rim, sampled per
    /// frame so designs can follow the time of day.
    func rimTint(at date: Date) -> Color
}

extension GlassDesign {
    /// Plain glass catches plain white light.
    func rimTint(at date: Date) -> Color { .white }
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
        // Grain is baked into the layer's rasterized image; the 20%
        // opacity that used to live on the SwiftUI mesh moves out here.
        AnyView(SolarAuroraLayer(paused: paused).opacity(0.2))
    }

    /// The rim catches the aurora's own light: the mesh's center color,
    /// lifted toward white, tracking the sun like the ambient layer does.
    func rimTint(at date: Date) -> Color {
        let accent = AuroraPalette.rimAccent(forElevation: SolarPosition.elevation(
            latitude: SolarAuroraLayer.location.latitude,
            longitude: SolarAuroraLayer.location.longitude,
            date: date))
        return Color(red: accent.red, green: accent.green, blue: accent.blue)
    }
}

/// Sunlight through water: solar-keyed water with drifting caustic webs.
struct CausticsDesign: GlassDesign {
    let id = "caustics"
    let name = "Caustics"
    func ambientLayer(paused: Bool) -> AnyView {
        AnyView(CausticsLayer(paused: paused).opacity(0.35))
    }

    func rimTint(at date: Date) -> Color {
        let accent = CausticsPalette.rimAccent(forElevation: SolarPosition.elevation(
            latitude: SolarAuroraLayer.location.latitude,
            longitude: SolarAuroraLayer.location.longitude,
            date: date))
        return Color(red: accent.red, green: accent.green, blue: accent.blue)
    }
}

/// Every available design, in menu order. The first entry is the default
/// and the fallback for unknown persisted ids.
@MainActor
enum DesignCatalog {
    static let all: [any GlassDesign] = [
        StillGlassDesign(),
        SolarAuroraDesign(),
        CausticsDesign(),
    ]

    static func design(withID id: String) -> any GlassDesign {
        all.first { $0.id == id } ?? all[0]
    }
}
