import AVFoundation

@MainActor
final class CabinNotchFilterPlugin: AudioEffectPlugin {
    let displayName = "Cabin Resonance Notch"
    private let processor = RealtimeDSPNode(.notch)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var frequency: Float = 135 { didSet { processor.set(1, min(max(frequency, 100), 200)) } }
    var qFactor: Float = 6 { didSet { processor.set(2, qFactor) } }
    var gain: Float = -6 { didSet { processor.set(3, gain) } }

    init() {
        processor.set(1, min(max(frequency, 100), 200))
        processor.set(2, qFactor)
        processor.set(3, gain)
        processor.enable(isEnabled)
    }
}
