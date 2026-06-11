import Foundation
import Testing
@testable import GlassClockCore

private let range: ClosedRange<CGFloat> = 0.5...2.5

@Test func crossingNaturalSizeTicksBothDirections() {
    #expect(ZoomDetents.shouldTick(from: 0.95, to: 1.05, range: range))
    #expect(ZoomDetents.shouldTick(from: 1.05, to: 0.95, range: range))
}

@Test func landingExactlyOnNaturalTicksBothDirections() {
    #expect(ZoomDetents.shouldTick(from: 1.05, to: 1.0, range: range))
    #expect(ZoomDetents.shouldTick(from: 0.95, to: 1.0, range: range))
}

@Test func leavingNaturalDoesNotTick() {
    #expect(!ZoomDetents.shouldTick(from: 1.0, to: 0.9, range: range))
    #expect(!ZoomDetents.shouldTick(from: 1.0, to: 1.1, range: range))
}

@Test func arrivingAtLimitsTicks() {
    #expect(ZoomDetents.shouldTick(from: 0.6, to: 0.5, range: range))
    #expect(ZoomDetents.shouldTick(from: 2.4, to: 2.5, range: range))
}

@Test func pinnedAtLimitStaysSilent() {
    #expect(!ZoomDetents.shouldTick(from: 0.5, to: 0.5, range: range))
    #expect(!ZoomDetents.shouldTick(from: 2.5, to: 2.5, range: range))
}

@Test func midRangeMovementIsSilent() {
    #expect(!ZoomDetents.shouldTick(from: 1.5, to: 1.6, range: range))
}
