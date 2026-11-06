import AVFoundation

@MainActor
final class StereoWidthCollapsePlugin: AudioEffectPlugin {
    let displayName = "Stereo Width Collapse"
    private let processor = RealtimeDSPNode(.collapse)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var width: Float = 0.35 { didSet { processor.set(1, width) } }

    init() {
        processor.set(1, width)
        processor.enable(isEnabled)
    }
}
