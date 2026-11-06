import AVFoundation

@MainActor
final class TransientShaperPlugin: AudioEffectPlugin {
    let displayName = "Transient Shaper"
    private let processor = RealtimeDSPNode(.transient)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var attack: Float = 6 { didSet { processor.set(1, attack) } }
    var sustain: Float = -3 { didSet { processor.set(2, sustain) } }

    init() {
        processor.set(1, attack)
        processor.set(2, sustain)
        processor.enable(isEnabled)
    }
}
