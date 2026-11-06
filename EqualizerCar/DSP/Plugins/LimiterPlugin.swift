import AVFoundation

@MainActor
final class LimiterPlugin: AudioEffectPlugin {
    let displayName = "Limiter"
    private let processor = RealtimeDSPNode(.limiter)
    var node: AVAudioNode { processor.node }
    var isEnabled = true { didSet { processor.enable(isEnabled) } }
    var ceiling: Float = -1 { didSet { processor.set(1, ceiling) } }
    var release: Float = 0.08 { didSet { processor.set(2, release) } }

    init() {
        processor.set(1, ceiling)
        processor.set(2, release)
        processor.enable(isEnabled)
    }
}
