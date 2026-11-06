import AVFoundation

@MainActor
final class ClipperProtectionPlugin: AudioEffectPlugin {
    let displayName = "Output Protection"
    private let processor = RealtimeDSPNode(.limiter)
    var node: AVAudioNode { processor.node }
    var isEnabled = true { didSet { processor.enable(isEnabled) } }
    var ceiling: Float = -0.1 { didSet { processor.set(1, min(ceiling, -0.1)) } }
    var release: Float = 0.035 { didSet { processor.set(2, release) } }

    init() {
        processor.set(1, min(ceiling, -0.1))
        processor.set(2, release)
        processor.enable(isEnabled)
    }
}
