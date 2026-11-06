import AVFoundation

@MainActor
final class StereoWideningPlugin: AudioEffectPlugin {
    let displayName = "Stereo Widening"
    private let processor = RealtimeDSPNode(.width)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var intensity: Float = 0.75 { didSet { processor.set(1, intensity) } }

    init() {
        processor.set(1, intensity)
        processor.enable(isEnabled)
    }
}
