import Foundation

/// A deterministic, seamlessly tileable grayscale caustics field: bright
/// Voronoi cell edges, like sunlight webbing on a pool floor. The app
/// rasterizes this once and lets the render server drift it.
public enum CausticsTile {
    /// size×size luminance bytes, row-major.
    public static func luminance(
        size: Int,
        featureCount: Int = 14,
        lineScale: Double = 6.5,
        sharpness: Double = 2.4,
        seed: UInt64 = 9
    ) -> [UInt8] {
        precondition(featureCount >= 2, "caustic web needs at least two cells")
        var rng = SplitMix64(seed: seed)
        let features = (0..<featureCount).map { _ in
            SIMD2(rng.unitDouble(), rng.unitDouble())
        }
        var bytes = [UInt8](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let point = SIMD2(Double(x) / Double(size), Double(y) / Double(size))
                var nearest = Double.infinity
                var second = Double.infinity
                for feature in features {
                    let distance = toroidalDistance(point, feature)
                    if distance < nearest {
                        second = nearest
                        nearest = distance
                    } else if distance < second {
                        second = distance
                    }
                }
                // Cell edges have F2 ≈ F1; that's where the light webs.
                let edge = max(0, 1 - (second - nearest) * lineScale)
                bytes[y * size + x] = UInt8(min(255, pow(edge, sharpness) * 255))
            }
        }
        return bytes
    }

    /// Distance on the unit torus, so the field tiles seamlessly.
    static func toroidalDistance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        var dx = abs(a.x - b.x); dx = min(dx, 1 - dx)
        var dy = abs(a.y - b.y); dy = min(dy, 1 - dy)
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Tiny deterministic RNG so tiles are reproducible (and testable).
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unitDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
