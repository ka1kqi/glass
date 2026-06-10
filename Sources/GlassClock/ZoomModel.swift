import Foundation
import Combine

/// The clock's zoom level: adjusted by pinch/scroll on the panel, clamped
/// to sane bounds, and persisted across launches.
@MainActor
final class ZoomModel: ObservableObject {
    static let range: ClosedRange<CGFloat> = 0.5...2.5
    private static let defaultsKey = "GlassScale"

    @Published var scale: CGFloat {
        didSet { UserDefaults.standard.set(Double(scale), forKey: Self.defaultsKey) }
    }

    init() {
        let saved = CGFloat(UserDefaults.standard.double(forKey: Self.defaultsKey))
        scale = saved > 0 ? saved.clamped(to: Self.range) : 1.0
    }

    /// Multiplies the current scale by `factor`, staying within bounds.
    func zoom(by factor: CGFloat) {
        scale = (scale * factor).clamped(to: Self.range)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
