import AVFoundation

@MainActor
final class ReverbPlugin: AudioEffectPlugin {
    let displayName = "Reverb"
    private let processor = RealtimeDSPNode(.reverb)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var amount: Float = 0 {
        didSet { processor.set(1, amount); isEnabled = amount > 0 }
    }
    var size: Float = 0.45 { didSet { processor.set(2, size) } }
    var damping: Float = 0.35 { didSet { processor.set(3, damping) } }
    init() {
        processor.set(1, amount); processor.set(2, size); processor.set(3, damping)
        processor.enable(false)
    }
}
