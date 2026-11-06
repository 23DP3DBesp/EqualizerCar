import AVFoundation

@MainActor
final class PhaseInverterPlugin: AudioEffectPlugin {
    let displayName = "Polarity Inversion"
    private let processor = RealtimeDSPNode(.phase)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }

    init() {
        processor.enable(isEnabled)
    }
}
