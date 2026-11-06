import AVFoundation

@MainActor
final class TapeSaturationPlugin: AudioEffectPlugin {
    let displayName = "Tape Saturation"
    private let processor = RealtimeDSPNode(.saturation)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var drive: Float = 0.35 { didSet { processor.set(1, drive) } }
    var mix: Float = 0.65 { didSet { processor.set(2, mix) } }

    init() {
        processor.set(1, drive)
        processor.set(2, mix)
        processor.enable(isEnabled)
    }
}
