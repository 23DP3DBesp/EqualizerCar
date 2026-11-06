import AVFoundation

@MainActor
final class FMDynamicExciterPlugin: AudioEffectPlugin {
    let displayName = "High-band Exciter"
    private let processor = RealtimeDSPNode(.exciter)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var intensity: Float = 0.35 { didSet { processor.set(1, intensity) } }

    init() {
        processor.set(1, intensity)
        processor.enable(isEnabled)
    }
}
