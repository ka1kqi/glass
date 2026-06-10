import Foundation
import Combine

/// Publishes the current "9:41"-style time string, updating just after
/// each minute boundary.
@MainActor
public final class ClockModel: ObservableObject {
    @Published public private(set) var timeString: String

    // The loop holds self weakly, so it exits on its own after the model
    // is deallocated; no deinit cancellation needed (deinit cannot touch
    // MainActor state under Swift 6 anyway).
    private var tickLoop: Task<Void, Never>?

    public init() {
        timeString = ClockFormatter.timeString(for: Date())
        tickLoop = Task { [weak self] in
            while true {
                let interval = ClockFormatter.intervalToNextMinute(from: Date())
                // +50ms so we land safely past the boundary.
                try? await Task.sleep(
                    nanoseconds: UInt64((interval + 0.05) * 1_000_000_000))
                guard let self else { return }
                self.timeString = ClockFormatter.timeString(for: Date())
            }
        }
    }
}
