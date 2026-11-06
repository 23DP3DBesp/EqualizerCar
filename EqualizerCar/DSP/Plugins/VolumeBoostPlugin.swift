import AVFoundation

@MainActor
final class VolumeBoostPlugin: AudioEffectPlugin {
    let displayName = "Volume Boost"
    private let processor = RealtimeDSPNode(.gain)
    var node: AVAudioNode { processor.node }
    var isEnabled = true { didSet { processor.enable(isEnabled) } }
    var multiplier: Float = 1 { didSet { processor.set(1, 20 * log10(min(max(multiplier, 1), 3))) } }

    init() {
        processor.set(1, 20 * log10(min(max(multiplier, 1), 3)))
        processor.enable(isEnabled)
    }
}
