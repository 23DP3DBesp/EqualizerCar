import AVFoundation

@MainActor
final class Logic7SpatializerPlugin: AudioEffectPlugin {
    let displayName = "Stereo3D Logic 7"
    let delayNode = AVAudioUnitDelay()

    var node: AVAudioNode { delayNode }

    var isEnabled: Bool = false {
        didSet { applyState() }
    }

    var ambience: Float = 0.35 {
        didSet { applyState() }
    }

    var centerFocus: Float = 0.45 {
        didSet { applyState() }
    }

    init() {
        delayNode.delayTime = 0.018
        delayNode.feedback = 4
        delayNode.lowPassCutoff = 9_500
        delayNode.wetDryMix = 0
    }

    private func applyState() {
        let ambience = min(max(ambience, 0), 1)
        let centerFocus = min(max(centerFocus, 0), 1)
        delayNode.delayTime = TimeInterval(0.010 + 0.022 * Double(ambience))
        delayNode.feedback = 2 + ambience * 10
        delayNode.lowPassCutoff = 7_500 + centerFocus * 4_500
        delayNode.wetDryMix = isEnabled ? min(max(ambience * 34, 0), 34) : 0
    }
}
