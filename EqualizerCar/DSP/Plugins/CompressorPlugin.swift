import AVFoundation

@MainActor
final class CompressorPlugin: AudioEffectPlugin {
    let displayName = "Compressor"
    private let processor = RealtimeDSPNode(.compressor)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var threshold: Float = -18 { didSet { processor.set(1, threshold) } }
    var ratio: Float = 3 { didSet { processor.set(2, ratio) } }
    var attack: Float = 0.012 { didSet { processor.set(3, attack) } }
    var release: Float = 0.18 { didSet { processor.set(4, release) } }

    init() {
        processor.set(1, threshold)
        processor.set(2, ratio)
        processor.set(3, attack)
        processor.set(4, release)
        processor.enable(isEnabled)
    }
}
