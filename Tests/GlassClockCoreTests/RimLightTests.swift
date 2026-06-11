import Foundation
import Testing
@testable import GlassClockCore

private let panel = CGRect(x: 100, y: 100, width: 340, height: 150)

@Test func cursorAboveLightsTheTop() {
    // Screen coords are y-up; SwiftUI angles y-down, so "above" is −π/2.
    let light = RimLight.compute(panel: panel, mouse: CGPoint(x: panel.midX, y: panel.maxY + 50))
    #expect(abs(light.angle - (-Double.pi / 2)) < 0.001)
    #expect(light.intensity == 1)
}

@Test func cursorRightLightsTheRight() {
    let light = RimLight.compute(panel: panel, mouse: CGPoint(x: panel.maxX + 50, y: panel.midY))
    #expect(abs(light.angle) < 0.001)
    #expect(light.intensity == 1)
}

@Test func cursorBelowAndLeftFlipCorrectly() {
    let below = RimLight.compute(panel: panel, mouse: CGPoint(x: panel.midX, y: panel.minY - 50))
    #expect(abs(below.angle - Double.pi / 2) < 0.001)
    let left = RimLight.compute(panel: panel, mouse: CGPoint(x: panel.minX - 50, y: panel.midY))
    #expect(abs(abs(left.angle) - Double.pi) < 0.001)
}

@Test func intensityFallsOffMonotonicallyToZero() {
    let halfDiagonal = (panel.width * panel.width + panel.height * panel.height)
        .squareRoot() / 2
    func intensity(atRimDistance d: CGFloat) -> Double {
        RimLight.compute(
            panel: panel,
            mouse: CGPoint(x: panel.midX + halfDiagonal + d, y: panel.midY)).intensity
    }
    #expect(intensity(atRimDistance: 100) == 1)          // inside grace zone
    let near = intensity(atRimDistance: 200)
    let far = intensity(atRimDistance: 500)
    #expect(near > far)
    #expect(intensity(atRimDistance: 700) == 0)          // beyond 600
}

@Test func nilPanelIsDark() {
    let light = RimLight.compute(panel: nil, mouse: .zero)
    #expect(light.intensity == 0)
}
