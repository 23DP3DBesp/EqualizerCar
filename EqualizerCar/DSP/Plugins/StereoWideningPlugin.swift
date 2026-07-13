import AVFoundation

@MainActor
final class StereoWideningPlugin: AudioEffectPlugin {
    let displayName = "Stereo Widening"
    let delayNode = AVAudioUnitDelay()

    var node: AVAudioNode { delayNode }

    var isEnabled: Bool = false {
        didSet {
            applyState()
        }
    }

    var intensity: Float = 0.75 {
        didSet {
            applyState()
        }
    }

    init() {
        delayNode.delayTime = 0.012
        delayNode.feedback = 0
        delayNode.lowPassCutoff = 16_000
        delayNode.wetDryMix = 0
    }

    private func applyState() {
        delayNode.delayTime = TimeInterval(0.006 + (0.018 * Double(clampedIntensity)))
        delayNode.wetDryMix = isEnabled ? min(max(clampedIntensity * 70, 0), 70) : 0
    }

    private var clampedIntensity: Float {
        min(max(intensity, 0), 1)
    }
}
