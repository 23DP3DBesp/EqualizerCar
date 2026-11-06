import AVFoundation

@MainActor
final class BassBoostPlugin: AudioEffectPlugin {
    let displayName = "Bass Boost"
    private let processor = RealtimeDSPNode(.bass)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var intensity: Float = 8 { didSet { processor.set(1, intensity) } }
    var frequency: Float = 80 { didSet { processor.set(2, frequency) } }

    init() {
        processor.set(1, intensity)
        processor.set(2, frequency)
        processor.enable(isEnabled)
    }
}
