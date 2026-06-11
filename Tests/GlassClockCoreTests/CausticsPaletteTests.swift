import Foundation
import Testing
@testable import GlassClockCore

@Test func waterPaletteHasThreeStops() {
    for elevation in stride(from: -90.0, through: 90.0, by: 10.0) {
        #expect(CausticsPalette.colors(forElevation: elevation).count == 3)
    }
}

@Test func waterPaletteClampsAndHitsAnchors() {
    #expect(CausticsPalette.colors(forElevation: -60)
        == CausticsPalette.colors(forElevation: -12))
    #expect(CausticsPalette.colors(forElevation: 70)
        == CausticsPalette.colors(forElevation: 25))
    #expect(CausticsPalette.colors(forElevation: 25)[0] == AuroraColor(hex: 0x57B8CE))
}

@Test func waterMidpointsInterpolate() {
    let dusk = CausticsPalette.colors(forElevation: -4)
    let golden = CausticsPalette.colors(forElevation: 3)
    let mid = CausticsPalette.colors(forElevation: -0.5)
    for i in 0..<3 {
        let expected = AuroraColor.lerp(dusk[i], golden[i], 0.5)
        #expect(abs(mid[i].red - expected.red) < 0.001)
        #expect(abs(mid[i].green - expected.green) < 0.001)
        #expect(abs(mid[i].blue - expected.blue) < 0.001)
    }
}

@Test func waterRimAccentReadsAsLight() {
    for elevation in stride(from: -90.0, through: 90.0, by: 15.0) {
        let accent = CausticsPalette.rimAccent(forElevation: elevation)
        #expect(accent.red >= 0.6 && accent.green >= 0.6 && accent.blue >= 0.6)
    }
}

@Test func auroraPaletteUnchangedByRefactor() {
    // Pin a couple of pre-refactor values so the extraction is provably
    // behavior-preserving.
    #expect(AuroraPalette.colors(forElevation: -4)[0] == AuroraColor(hex: 0x29005E))
    let dawn = AuroraPalette.colors(forElevation: -4)
    let golden = AuroraPalette.colors(forElevation: 3)
    let mid = AuroraPalette.colors(forElevation: -0.5)
    #expect(abs(mid[0].red - AuroraColor.lerp(dawn[0], golden[0], 0.5).red) < 0.001)
}
