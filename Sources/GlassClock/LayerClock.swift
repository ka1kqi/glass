import QuartzCore

/// The standard CoreAnimation freeze/resume idiom, shared by every
/// design view that animates in the render server.
enum LayerClock {
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
