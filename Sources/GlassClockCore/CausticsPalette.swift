import Foundation

/// Water colors for the Caustics design: a 3-stop vertical gradient
/// (top → bottom) keyed to solar elevation, same anchors as the aurora.
public enum CausticsPalette {
    static let anchors: [(elevation: Double, colors: [AuroraColor])] = [
        (-12, night), (-4, dusk), (3, golden), (25, day),
    ]

    /// Deep navy night water.
    static let night = stops(0x06121F, 0x0A1C2E, 0x040B14)
    /// Teal dusk.
    static let dusk = stops(0x123246, 0x1A4A5E, 0x0A2433)
    /// Warm shallows at golden hour.
    static let golden = stops(0x2E6E7A, 0x3E8E96, 0x16414E)
    /// Bright midday aqua.
    static let day = stops(0x57B8CE, 0x7FD2E0, 0x2E7E96)

    /// Gradient stops for the given elevation, clamped outside anchors.
    public static func colors(forElevation elevation: Double) -> [AuroraColor] {
        PaletteMath.interpolate(anchors: anchors, elevation: elevation)
    }

    /// Rim arc accent: the mid water color lifted 60% toward white.
    public static func rimAccent(forElevation elevation: Double) -> AuroraColor {
        AuroraColor.lerp(
            colors(forElevation: elevation)[1],
            AuroraColor(red: 1, green: 1, blue: 1),
            0.6)
    }

    private static func stops(_ hex: UInt32...) -> [AuroraColor] {
        hex.map(AuroraColor.init(hex:))
    }
}
