import AVFoundation

@MainActor
final class ParametricNotchPlugin: AudioEffectPlugin {
    let displayName = "Parametric Notch"
    private let processor = RealtimeDSPNode(.notch)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var frequency: Float = 1000 { didSet { processor.set(1, frequency) } }
    var qFactor: Float = 4 { didSet { processor.set(2, qFactor) } }
    var depth: Float = -12 { didSet { processor.set(3, depth) } }

    init() {
        processor.set(1, frequency)
        processor.set(2, qFactor)
        processor.set(3, depth)
        processor.enable(isEnabled)
    }
}
