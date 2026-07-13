import AVFoundation

@MainActor
final class ReverbPlugin: AudioEffectPlugin {
    let displayName = "Reverb"
    let reverbNode = AVAudioUnitReverb()

    var node: AVAudioNode { reverbNode }

    var isEnabled: Bool = false {
        didSet {
            reverbNode.wetDryMix = isEnabled ? amount : 0
        }
    }

    var amount: Float = 0 {
        didSet {
            applyState()
        }
    }

    var size: Float = 0.45 {
        didSet {
            applyPreset()
        }
    }

    var damping: Float = 0.35 {
        didSet {
            applyPreset()
        }
    }

    init() {
        applyPreset()
        reverbNode.wetDryMix = 0
    }

    private func applyState() {
        reverbNode.wetDryMix = isEnabled ? min(max(amount, 0), 100) : 0
        isEnabled = amount > 0
    }

    private func applyPreset() {
        let clampedSize = min(max(size, 0), 1)
        let clampedDamping = min(max(damping, 0), 1)

        switch (clampedSize, clampedDamping) {
        case (..<0.33, ..<0.5):
            reverbNode.loadFactoryPreset(.smallRoom)
        case (..<0.33, _):
            reverbNode.loadFactoryPreset(.smallRoom)
        case (..<0.70, ..<0.5):
            reverbNode.loadFactoryPreset(.mediumHall)
        case (..<0.70, _):
            reverbNode.loadFactoryPreset(.mediumRoom)
        case (_, ..<0.5):
            reverbNode.loadFactoryPreset(.largeHall)
        default:
            reverbNode.loadFactoryPreset(.largeRoom)
        }
        reverbNode.wetDryMix = isEnabled ? min(max(amount, 0), 100) : 0
    }
}
