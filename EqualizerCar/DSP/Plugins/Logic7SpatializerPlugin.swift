import AVFoundation

@MainActor
final class Logic7SpatializerPlugin: AudioEffectPlugin {
    let displayName = "Stereo3D"
    private let processor = RealtimeDSPNode(.stereo3D)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var ambience: Float = 0.35 { didSet { processor.set(1, ambience) } }
    var centerFocus: Float = 0.45 { didSet { processor.set(2, centerFocus) } }

    init() {
        processor.set(1, ambience)
        processor.set(2, centerFocus)
        processor.enable(isEnabled)
    }
}
