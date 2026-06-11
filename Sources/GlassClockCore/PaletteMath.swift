import Foundation

/// Shared anchor-interpolation for elevation-keyed palettes.
enum PaletteMath {
    /// Linear interpolation between adjacent anchor palettes, clamped
    /// outside the anchor range. Anchors must be sorted ascending.
    static func interpolate(
        anchors: [(elevation: Double, colors: [AuroraColor])],
        elevation: Double
    ) -> [AuroraColor] {
        guard elevation > anchors.first!.elevation else { return anchors.first!.colors }
        guard elevation < anchors.last!.elevation else { return anchors.last!.colors }
        for i in 0..<(anchors.count - 1) {
            let low = anchors[i], high = anchors[i + 1]
            guard elevation <= high.elevation else { continue }
            let t = (elevation - low.elevation) / (high.elevation - low.elevation)
            return zip(low.colors, high.colors).map { AuroraColor.lerp($0, $1, t) }
        }
        // Unreachable: the guards bound elevation strictly inside the range.
        return anchors.last!.colors
    }
}
