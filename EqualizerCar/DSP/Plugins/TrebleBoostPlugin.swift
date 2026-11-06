import AVFoundation

@MainActor
final class TrebleBoostPlugin: AudioEffectPlugin {
    let displayName = "Treble Boost"
    private let processor = RealtimeDSPNode(.treble)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }

    init() {
        processor.enable(isEnabled)
    }
}
