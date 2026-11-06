import AVFoundation

@MainActor
final class VirtualSubwooferPlugin: AudioEffectPlugin {
    let displayName = "Virtual Subwoofer"
    private let processor = RealtimeDSPNode(.virtualSub)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var mix: Float = 0.5 { didSet { processor.set(1, mix) } }
    var cutoffFrequency: Float = 55 { didSet { processor.set(2, cutoffFrequency) } }

    init() {
        processor.set(1, mix)
        processor.set(2, cutoffFrequency)
        processor.enable(isEnabled)
    }
}
