import AVFoundation

@MainActor
final class LoudnessPlugin: AudioEffectPlugin {
    let displayName = "Loudness"
    private let processor = RealtimeDSPNode(.loudness)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }

    init() {
        processor.enable(isEnabled)
    }
}
