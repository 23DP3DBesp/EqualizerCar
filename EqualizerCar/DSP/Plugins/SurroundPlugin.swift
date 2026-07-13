import AVFoundation

@MainActor
final class SurroundPlugin: AudioEffectPlugin {
    let displayName = "Surround"
    let reverbNode = AVAudioUnitReverb()

    var node: AVAudioNode { reverbNode }

    var isEnabled: Bool = false {
        didSet {
            applyState()
        }
    }

    var amount: Float = 0.55 {
        didSet {
            applyState()
        }
    }

    init() {
        reverbNode.loadFactoryPreset(.largeHall)
        reverbNode.wetDryMix = 0
    }

    private func applyState() {
        reverbNode.wetDryMix = isEnabled ? min(max(amount * 55, 0), 55) : 0
    }
}
