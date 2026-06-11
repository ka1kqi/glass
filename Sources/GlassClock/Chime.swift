import AVFoundation
import Foundation

/// A soft synthesized glass "ting" on the hour. Off by default; persisted.
@MainActor
final class Chime {
    private static let defaultsKey = "HourlyChime"

    var isOn: Bool {
        didSet {
            UserDefaults.standard.set(isOn, forKey: Self.defaultsKey)
            isOn ? scheduleNextHour() : cancel()
        }
    }

    /// Skips the ting while ambient work is paused (asleep, hidden,
    /// Low Power Mode…). Wired to AmbientPacer by the app delegate.
    var isPaused: () -> Bool = { false }

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var timer: Timer?

    init() {
        isOn = UserDefaults.standard.bool(forKey: Self.defaultsKey)
        if isOn { scheduleNextHour() }
    }

    private func scheduleNextHour() {
        cancel()
        let next = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOn else { return }
                if !self.isPaused() { self.play() }
                self.scheduleNextHour()
            }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
    }

    private func play() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        // A failed engine just means no decoration this hour.
        guard let buffer = Self.tingBuffer(format: format),
              (try? engine.start()) != nil else { return }
        self.engine = engine
        self.player = player
        player.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                self?.engine?.stop()
                self?.engine = nil
                self?.player = nil
            }
        }
        player.play()
    }

    /// Decaying inharmonic sine partials — the sound of a tapped
    /// wineglass. Glass partials are not harmonic; the ~2.76× and ~5.1×
    /// ratios are what make it read as glass rather than a bell.
    private static func tingBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * 1.8)
        guard sampleRate > 0, format.channelCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else { return nil }
        buffer.frameLength = frames
        let partials: [(frequency: Double, amplitude: Double, decay: Double)] = [
            (1318.5, 0.20, 3.0),
            (3638.0, 0.10, 5.5),
            (6724.0, 0.05, 8.0),
        ]
        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            var sample = 0.0
            for p in partials {
                sample += p.amplitude * sin(2 * .pi * p.frequency * t) * exp(-p.decay * t)
            }
            sample *= min(1, t / 0.005)  // 5ms attack so it doesn't click
            for channel in 0..<Int(format.channelCount) {
                buffer.floatChannelData?[channel][frame] = Float(sample)
            }
        }
        return buffer
    }
}
