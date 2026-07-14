import AVFoundation

@MainActor
final class PhaseInverterPlugin: AudioEffectPlugin {
    let displayName = "Phase Inverter (sub)"
    // Currently a placeholder mixer node — real per-subwoofer inversion requires separate subwoofer routing
    let mixer = AVAudioMixerNode()

    var node: AVAudioNode { mixer }

    var isEnabled: Bool = false {
        didSet {
            // Placeholder: no-op. Implement real inversion when subwoofer path available (multi-channel output).
        }
    }

    init() {
        // default mixer settings
        mixer.outputVolume = 1
    }
}
