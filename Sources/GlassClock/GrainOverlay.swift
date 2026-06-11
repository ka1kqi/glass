import SwiftUI
import AppKit

/// Static film grain that keeps low-opacity gradients from banding.
/// Generated once per launch (never animated — animated noise is the
/// expensive kind) and tiled across the panel.
@MainActor
enum Grain {
    static let image: NSImage = {
        let size = 128
        var bytes = [UInt8](repeating: 0, count: size * size)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cgImage = CGImage(
            width: size, height: size,
            bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)!
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }()
}

struct GrainOverlay: View {
    /// On-screen strength; bake-time callers compensate for downstream
    /// layer opacity (e.g. 0.2 baked × 0.2 layer ≈ the classic 4%).
    var opacity: Double = 0.04

    var body: some View {
        Image(nsImage: Grain.image)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }
}
