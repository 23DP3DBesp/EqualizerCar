import AVFoundation

@MainActor
final class StereoWidthCollapsePlugin: AudioEffectPlugin {
    let displayName = "Stereo Width Collapse"
    private let passThroughNode = AVAudioUnitEQ(numberOfBands: 0)

    var node: AVAudioNode { passThroughNode }

    var isEnabled: Bool = false {
        didSet { applyState() }
    }

    var width: Float = 1 {
        didSet { applyState() }
    }

    init() {
        applyState()
    }

    private func applyState() {
        // Keep this plugin as guaranteed pass-through. The previous MatrixMixer AU
        // can mute the whole AVAudioEngine graph on some routes even when disabled.
        passThroughNode.globalGain = 0
    }
}
