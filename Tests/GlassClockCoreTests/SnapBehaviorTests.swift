import Foundation
import CoreGraphics
import Testing
@testable import GlassClockCore

// visibleFrame origins are rarely (0,0) in real life (Dock, second
// displays), so test with a shifted screen.
private let screen = CGRect(x: 100, y: 50, width: 1440, height: 800)
private let panelSize = CGSize(width: 340, height: 150)

private func panel(x: CGFloat, y: CGFloat) -> CGRect {
    CGRect(origin: CGPoint(x: x, y: y), size: panelSize)
}

@Test func nearLeftEdgeSnapsXOnly() {
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 110, y: 400), in: screen)
    #expect(snapped == CGPoint(x: 100, y: 400))
}

@Test func nearRightEdgeSnapsFlush() {
    // Right edge of screen is at 1540; panel maxX 1530 is 10 away.
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 1190, y: 400), in: screen)
    #expect(snapped == CGPoint(x: 1540 - 340, y: 400))
}

@Test func nearBottomLeftCornerSnapsBothAxes() {
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 115, y: 60), in: screen)
    #expect(snapped == CGPoint(x: 100, y: 50))
}

@Test func nearTopEdgeSnapsYFlush() {
    // Top of screen is at 850; panel maxY at 840 is 10 away.
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 700, y: 690), in: screen)
    #expect(snapped == CGPoint(x: 700, y: 850 - 150))
}

@Test func centeredPanelDoesNotSnap() {
    #expect(SnapBehavior.snappedOrigin(for: panel(x: 650, y: 375), in: screen) == nil)
}

@Test func exactlyAtThresholdStillSnaps() {
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 124, y: 400), in: screen)
    #expect(snapped == CGPoint(x: 100, y: 400))
}

@Test func justBeyondThresholdDoesNotSnap() {
    #expect(SnapBehavior.snappedOrigin(for: panel(x: 125, y: 400), in: screen) == nil)
}
