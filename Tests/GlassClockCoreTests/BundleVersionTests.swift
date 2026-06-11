import Foundation
import Testing
@testable import GlassClockCore

@Test func olderWhenComponentsSmaller() {
    #expect(BundleVersion.isVersion("1.2.0", olderThan: "1.3.0"))
    #expect(BundleVersion.isVersion("1.2.0", olderThan: "2.0.0"))
    #expect(!BundleVersion.isVersion("1.3.0", olderThan: "1.3.0"))
    #expect(!BundleVersion.isVersion("2.0.0", olderThan: "1.9.9"))
}

@Test func comparesNumericallyNotLexically() {
    // Lexical comparison would call "1.10.0" older than "1.9.0".
    #expect(BundleVersion.isVersion("1.9.0", olderThan: "1.10.0"))
    #expect(!BundleVersion.isVersion("1.10.0", olderThan: "1.9.0"))
}

@Test func missingComponentsCountAsZero() {
    #expect(!BundleVersion.isVersion("1.2", olderThan: "1.2.0"))
    #expect(BundleVersion.isVersion("1.2", olderThan: "1.2.1"))
    #expect(BundleVersion.isVersion("1", olderThan: "1.0.1"))
}

@Test func malformedComponentsCountAsZero() {
    #expect(BundleVersion.isVersion("1.x", olderThan: "1.1"))
    #expect(!BundleVersion.isVersion("1.1", olderThan: "1.x"))
}
