import Foundation

/// Mean-synodic lunar phase — accurate to roughly half a day, plenty for
/// an ambient glow.
public enum LunarPhase {
    /// Days in a mean synodic month.
    static let synodicMonth = 29.53058867
    /// The new moon of 2000-01-06 18:14 UTC, in seconds since 1970.
    static let epoch: TimeInterval = 947_182_440

    /// Phase fraction in [0, 1): 0 = new, 0.5 = full.
    public static func phase(at date: Date) -> Double {
        let days = (date.timeIntervalSince1970 - epoch) / 86_400
        let wrapped = (days / synodicMonth).truncatingRemainder(dividingBy: 1)
        return wrapped < 0 ? wrapped + 1 : wrapped
    }

    /// Illuminated fraction 0…1: 0 at new, 1 at full.
    public static func illumination(at date: Date) -> Double {
        (1 - cos(2 * .pi * phase(at: date))) / 2
    }
}

/// Colors for the Lunar Tide design: a constant night field (it does not
/// follow the sun — that's its identity) and a moonlight rim accent.
public enum LunarPalette {
    /// Top → bottom stops of the indigo night field.
    public static let field = [
        AuroraColor(hex: 0x0A0E1E),
        AuroraColor(hex: 0x101A33),
        AuroraColor(hex: 0x070B16),
    ]

    /// Silver-blue moonlight; a fuller moon lifts it further toward white.
    public static func rimAccent(illumination: Double) -> AuroraColor {
        let clamped = min(max(illumination, 0), 1)
        return AuroraColor.lerp(
            AuroraColor(hex: 0x9FB6D9),
            AuroraColor(red: 1, green: 1, blue: 1),
            0.35 + 0.35 * clamped)
    }
}
