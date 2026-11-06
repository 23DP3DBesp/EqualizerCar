import AVFoundation

@MainActor
final class SurroundPlugin: AudioEffectPlugin {
    let displayName = "Stereo Surround"
    private let processor = RealtimeDSPNode(.surround)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var amount: Float = 0.55 { didSet { processor.set(1, amount) } }

    init() {
        processor.set(1, amount)
        processor.enable(isEnabled)
    }
}
