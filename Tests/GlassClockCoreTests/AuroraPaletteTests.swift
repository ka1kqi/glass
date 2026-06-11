import Foundation
import Testing
@testable import GlassClockCore

@Test func hexInitializerSplitsChannels() {
    let color = AuroraColor(hex: 0xFF8040)
    #expect(abs(color.red - 1.0) < 0.005)
    #expect(abs(color.green - 0x80 / 255.0) < 0.005)
    #expect(abs(color.blue - 0x40 / 255.0) < 0.005)
}

@Test func lerpMixesChannelsLinearly() {
    let black = AuroraColor(hex: 0x000000)
    let white = AuroraColor(hex: 0xFFFFFF)
    let mid = AuroraColor.lerp(black, white, 0.5)
    #expect(abs(mid.red - 0.5) < 0.005)
    #expect(abs(mid.green - 0.5) < 0.005)
    #expect(abs(mid.blue - 0.5) < 0.005)
}

@Test func paletteAlwaysHasNineColors() {
    for elevation in stride(from: -90.0, through: 90.0, by: 7.5) {
        #expect(AuroraPalette.colors(forElevation: elevation).count == 9)
    }
}

@Test func deepNightClampsToNightAnchor() {
    #expect(AuroraPalette.colors(forElevation: -60) == AuroraPalette.colors(forElevation: -12))
}

@Test func highNoonClampsToDayAnchor() {
    #expect(AuroraPalette.colors(forElevation: 70) == AuroraPalette.colors(forElevation: 25))
}

@Test func anchorElevationsReturnAnchorPalettes() {
    // The −4° anchor is the dawn palette; spot-check its first color.
    let dawn = AuroraPalette.colors(forElevation: -4)
    #expect(dawn[0] == AuroraColor(hex: 0x29005E))
}

@Test func midpointsInterpolateBetweenAdjacentAnchors() {
    // −0.5° is halfway between the −4° (dawn) and +3° (golden) anchors.
    let dawn = AuroraPalette.colors(forElevation: -4)
    let golden = AuroraPalette.colors(forElevation: 3)
    let mid = AuroraPalette.colors(forElevation: -0.5)
    for i in 0..<9 {
        let expected = AuroraColor.lerp(dawn[i], golden[i], 0.5)
        #expect(abs(mid[i].red - expected.red) < 0.001)
        #expect(abs(mid[i].green - expected.green) < 0.001)
        #expect(abs(mid[i].blue - expected.blue) < 0.001)
    }
}

@Test func anchorBoundariesMatchLiteralColors() {
    // Guards clamp AT the boundary anchors too — straight to the literals.
    #expect(AuroraPalette.colors(forElevation: -12)[0] == AuroraColor(hex: 0x0B0B26))
    #expect(AuroraPalette.colors(forElevation: 25)[0] == AuroraColor(hex: 0xAFC8D8))
}

@Test func rimAccentLiftsCenterColorTowardWhite() {
    let center = AuroraPalette.colors(forElevation: 5)[4]
    let expected = AuroraColor.lerp(center, AuroraColor(red: 1, green: 1, blue: 1), 0.6)
    #expect(AuroraPalette.rimAccent(forElevation: 5) == expected)
}

@Test func rimAccentAlwaysReadsAsLight() {
    // The 0.6 lift toward white bounds every channel at ≥ 0.6, so the
    // rim arc stays visibly bright even on the near-black night palette.
    for elevation in stride(from: -90.0, through: 90.0, by: 5.0) {
        let accent = AuroraPalette.rimAccent(forElevation: elevation)
        #expect(accent.red >= 0.6 && accent.green >= 0.6 && accent.blue >= 0.6)
    }
}
