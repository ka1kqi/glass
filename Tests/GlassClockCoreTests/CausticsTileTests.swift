import Foundation
import Testing
@testable import GlassClockCore

@Test func toroidalDistanceWrapsTheShortWay() {
    let d = CausticsTile.toroidalDistance(SIMD2(0.05, 0.5), SIMD2(0.95, 0.5))
    #expect(abs(d - 0.1) < 0.0001)
    let symmetric = CausticsTile.toroidalDistance(SIMD2(0.95, 0.5), SIMD2(0.05, 0.5))
    #expect(abs(d - symmetric) < 0.0001)
}

@Test func tileIsDeterministicPerSeed() {
    #expect(CausticsTile.luminance(size: 64, seed: 9)
        == CausticsTile.luminance(size: 64, seed: 9))
    #expect(CausticsTile.luminance(size: 64, seed: 9)
        != CausticsTile.luminance(size: 64, seed: 23))
}

@Test func tileUsesTheFullLuminanceRange() {
    let bytes = CausticsTile.luminance(size: 128)
    #expect(bytes.count == 128 * 128)
    #expect(bytes.max()! >= 200)   // bright web lines
    #expect(bytes.min()! <= 30)    // dark cell interiors
}

@Test func tileWrapsSeamlessly() {
    // The jump across the wrapped edge should look like any interior
    // jump — statistically, not exactly (adjacent columns differ too).
    let size = 128
    let bytes = CausticsTile.luminance(size: size)
    func meanColumnDiff(_ a: Int, _ b: Int) -> Double {
        var total = 0.0
        for y in 0..<size {
            total += abs(Double(bytes[y * size + a]) - Double(bytes[y * size + b]))
        }
        return total / Double(size)
    }
    let wrapJump = meanColumnDiff(0, size - 1)
    var interior = 0.0
    for x in 0..<(size - 1) { interior += meanColumnDiff(x, x + 1) }
    interior /= Double(size - 1)
    // Tight bound: a broken wrap puts a hard seam at the edge, which
    // would blow far past ordinary column-to-column variation.
    #expect(wrapJump <= interior * 1.25 + 1)
}
