import SwiftUI
import GlassClockCore

/// The flagship ambient layer: a slowly drifting mesh gradient whose
/// palette follows the real sun's elevation at the timezone-approximated
/// location. 15 fps is the ceiling — the motion is glacial by design.
struct SolarAuroraLayer: View {
    var paused: Bool

    /// Resolved once per launch; a stale location only shifts the palette
    /// by minutes, invisible at this opacity.
    private static let location = TimeZoneLocation.coordinates()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: paused)) { context in
            let elevation = SolarPosition.elevation(
                latitude: Self.location.latitude,
                longitude: Self.location.longitude,
                date: context.date)
            MeshGradient(
                width: AuroraPalette.meshWidth,
                height: AuroraPalette.meshHeight,
                points: Self.points(at: context.date.timeIntervalSinceReferenceDate),
                colors: AuroraPalette.colors(forElevation: elevation).map {
                    Color(red: $0.red, green: $0.green, blue: $0.blue)
                })
        }
        .opacity(0.2)
        .allowsHitTesting(false)
    }

    /// Corners stay pinned and edge midpoints drift only along their own
    /// edge (MeshGradient requires boundary points on the boundary); the
    /// periods are mutually prime so the field never visibly repeats.
    private static func points(at t: TimeInterval) -> [SIMD2<Float>] {
        func drift(
            _ base: SIMD2<Float>,
            dx: Float, dy: Float,
            px: Double, py: Double
        ) -> SIMD2<Float> {
            SIMD2(
                base.x + dx * Float(sin(t * 2 * .pi / px)),
                base.y + dy * Float(cos(t * 2 * .pi / py)))
        }
        return [
            SIMD2(0, 0),
            drift(SIMD2(0.5, 0), dx: 0.18, dy: 0, px: 23, py: 1),
            SIMD2(1, 0),
            drift(SIMD2(0, 0.5), dx: 0, dy: 0.16, px: 1, py: 29),
            drift(SIMD2(0.5, 0.5), dx: 0.22, dy: 0.20, px: 37, py: 41),
            drift(SIMD2(1, 0.5), dx: 0, dy: 0.16, px: 1, py: 31),
            SIMD2(0, 1),
            drift(SIMD2(0.5, 1), dx: 0.18, dy: 0, px: 43, py: 1),
            SIMD2(1, 1),
        ]
    }
}
