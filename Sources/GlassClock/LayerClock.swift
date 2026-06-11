import QuartzCore

/// The standard CoreAnimation freeze/resume idiom, shared by every
/// design view that animates in the render server.
enum LayerClock {
    /// A repeating autoreversing ease-in-out wander between two values —
    /// the building block of every design's render-server drift.
    static func wander(_ keyPath: String, from: Double, to: Double, over seconds: Double) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = seconds
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    static func pause(_ layer: CALayer) {
        let now = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = now
    }

    static func resume(_ layer: CALayer) {
        let frozenAt = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        layer.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - frozenAt
    }
}
