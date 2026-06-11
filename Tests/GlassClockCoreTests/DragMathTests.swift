import Foundation
import Testing
@testable import GlassClockCore

@Test func steadyDragYieldsItsVelocity() {
    // 100 pt/s rightward, sampled every 20ms.
    let samples = (0...5).map { i in
        (time: Double(i) * 0.02, origin: CGPoint(x: Double(i) * 2, y: 0))
    }
    let v = DragMath.releaseVelocity(samples: samples, releasedAt: 0.1)
    #expect(abs(v.dx - 100) < 0.001)
    #expect(abs(v.dy) < 0.001)
}

@Test func flickThenHoldReleasesAtZero() {
    // Fast movement, then 300ms of stillness before release: every
    // sample is older than the 120ms window.
    let samples = (0...5).map { i in
        (time: Double(i) * 0.02, origin: CGPoint(x: Double(i) * 10, y: 0))
    }
    let v = DragMath.releaseVelocity(samples: samples, releasedAt: 0.1 + 0.3)
    #expect(v == .zero)
}

@Test func singleSampleReleasesAtZero() {
    let v = DragMath.releaseVelocity(
        samples: [(time: 0, origin: CGPoint(x: 5, y: 5))], releasedAt: 0.05)
    #expect(v == .zero)
}

@Test func emptySamplesReleaseAtZero() {
    #expect(DragMath.releaseVelocity(samples: [], releasedAt: 1) == .zero)
}
