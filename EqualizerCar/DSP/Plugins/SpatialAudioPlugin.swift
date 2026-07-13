import AVFoundation

@MainActor
final class SpatialAudioPlugin: AudioEffectPlugin {
    let displayName = "Spatial Audio"
    let delayNode = AVAudioUnitDelay()

    var node: AVAudioNode { delayNode }

    var isEnabled: Bool = false {
        didSet {
            applyState()
        }
    }

    var depth: Float = 0.35 {
        didSet {
            applyState()
        }
    }

    init() {
        delayNode.delayTime = 0.024
        delayNode.feedback = 14
        delayNode.lowPassCutoff = 11_000
        delayNode.wetDryMix = 0
    }

    private func applyState() {
        let clampedDepth = min(max(depth, 0), 1)
        delayNode.delayTime = TimeInterval(0.012 + (0.032 * Double(clampedDepth)))
        delayNode.feedback = min(max(clampedDepth * 22, 0), 22)
        delayNode.wetDryMix = isEnabled ? min(max(clampedDepth * 62, 0), 62) : 0
    }
}
