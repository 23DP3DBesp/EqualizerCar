import AVFoundation

@MainActor
final class MultibandCompressorPlugin: AudioEffectPlugin {
    let displayName = "Three-band Compressor"
    private let processor = RealtimeDSPNode(.multiband)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }

    init() {
        processor.enable(isEnabled)
    }
}
