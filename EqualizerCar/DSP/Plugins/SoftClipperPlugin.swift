import AVFoundation

@MainActor
final class SoftClipperPlugin: AudioEffectPlugin {
    let displayName = "Soft Clipper"
    let distortionNode = AVAudioUnitDistortion()

    var node: AVAudioNode { distortionNode }

    var isEnabled: Bool = false {
        didSet {
            applyState()
        }
    }

    var drive: Float = 0.08 {
        didSet {
            applyState()
        }
    }

    init() {
        distortionNode.loadFactoryPreset(.multiDistortedSquared)
        distortionNode.preGain = -6
        distortionNode.wetDryMix = 0
        applyState()
    }

    private func applyState() {
        distortionNode.wetDryMix = isEnabled ? min(max(drive * 100, 0), 12) : 0
    }
}
