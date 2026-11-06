import AVFoundation

@MainActor
final class SpatialAudioPlugin: AudioEffectPlugin {
    let displayName = "Spatial Audio"
    private let processor = RealtimeDSPNode(.spatial)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var depth: Float = 0.65 { didSet { processor.set(1, depth) } }

    init() {
        processor.set(1, depth)
        processor.enable(isEnabled)
    }
}
