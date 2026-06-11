import Foundation

/// An sRGB color value kept in core (no SwiftUI) so palette math stays
/// unit-testable; the app maps these onto SwiftUI colors.
public struct AuroraColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// 0xRRGGBB.
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    public static func lerp(_ a: AuroraColor, _ b: AuroraColor, _ t: Double) -> AuroraColor {
        AuroraColor(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t)
    }
}

/// Maps solar elevation to a 3×3 mesh palette, interpolating between
/// keyframes so the tint slides continuously through the day — never a
/// binary day/night flip.
public enum AuroraPalette {
    public static let meshWidth = 3
    public static let meshHeight = 3

    /// Keyframe palettes by the solar elevation (degrees) that anchors
    /// them, ascending. Row-major 3×3, top row first.
    static let anchors: [(elevation: Double, colors: [AuroraColor])] = [
        (-12, night), (-4, dawn), (3, golden), (25, day),
    ]

    /// Near-black indigo with faint violet.
    static let night = palette(
        0x0B0B26, 0x141433, 0x1B1040,
        0x10102E, 0x221546, 0x2A1B52,
        0x0B0B22, 0x191038, 0x0E0E26)

    /// Indigo → mauve → dusty rose.
    static let dawn = palette(
        0x29005E, 0x4F1B74, 0x9B6FA7,
        0x3A1466, 0x7A4E96, 0xCCB7C0,
        0x4F1B74, 0x9B6FA7, 0xD9A8B0)

    /// Coral → ember → honey amber.
    static let golden = palette(
        0xCF473B, 0xE5793F, 0xFCA34F,
        0xE5793F, 0xFDCF5A, 0xF1B457,
        0xFCA34F, 0xFDCF5A, 0xFCE49B)

    /// Cool, nearly neutral blue-white.
    static let day = palette(
        0xAFC8D8, 0xC2D4DF, 0xD7E3EA,
        0xB5D6E0, 0xC7E1E5, 0xDDE9EE,
        0xC2D4DF, 0xD7E3EA, 0xE8F0F4)

    /// 9 colors for the given elevation; clamps outside the anchor range.
    public static func colors(forElevation elevation: Double) -> [AuroraColor] {
        guard elevation > anchors.first!.elevation else { return anchors.first!.colors }
        guard elevation < anchors.last!.elevation else { return anchors.last!.colors }
        for i in 0..<(anchors.count - 1) {
            let low = anchors[i], high = anchors[i + 1]
            guard elevation <= high.elevation else { continue }
            let t = (elevation - low.elevation) / (high.elevation - low.elevation)
            return zip(low.colors, high.colors).map { AuroraColor.lerp($0, $1, t) }
        }
        // Unreachable: the guards bound elevation strictly inside the
        // anchor range, so the loop always returns.
        return anchors.last!.colors
    }

    /// The accent the rim's specular arc uses so reactive light matches
    /// the aurora's time of day: the mesh's center color lifted 60% toward
    /// white, which keeps every channel ≥ 0.6 — bright enough to read as
    /// light even over the near-black night palette.
    public static func rimAccent(forElevation elevation: Double) -> AuroraColor {
        AuroraColor.lerp(
            colors(forElevation: elevation)[4],
            AuroraColor(red: 1, green: 1, blue: 1),
            0.6)
    }

    private static func palette(_ hex: UInt32...) -> [AuroraColor] {
        hex.map(AuroraColor.init(hex:))
    }
}
