import Foundation
import Testing
@testable import GlassClockCore

@Test @MainActor func modelStartsWithFormattedCurrentTime() {
    let model = ClockModel()
    #expect(model.timeString.range(
        of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil)
}

@Test @MainActor func refreshUpdatesToCurrentFormattedTime() {
    let model = ClockModel()
    model.refresh()
    #expect(model.timeString.range(
        of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil)
}
