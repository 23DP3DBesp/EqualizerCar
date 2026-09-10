import AVFoundation
import AudioToolbox

@MainActor
final class ClipperProtectionPlugin: AudioEffectPlugin {
    let displayName = "Clipper Protection"
    let effectNode = AudioUnitEffectFactory.makeAppleEffect(subType: kAudioUnitSubType_PeakLimiter)

    var node: AVAudioNode { effectNode }

    var isEnabled: Bool = true {
        didSet {
            effectNode.auAudioUnit.shouldBypassEffect = !isEnabled
            applyParameters()
        }
    }

    var ceiling: Float = -0.1 {
        didSet { applyParameters() }
    }

    var release: Float = 0.035 {
        didSet { applyParameters() }
    }

    init() {
        effectNode.auAudioUnit.shouldBypassEffect = false
        applyParameters()
    }

    private func applyParameters() {
        AudioUnitParameterWriter.set(effectNode, candidates: ["ceiling", "limit", "threshold"], value: min(max(ceiling, -6), -0.1))
        AudioUnitParameterWriter.set(effectNode, candidates: ["release", "releasetime", "decay"], value: min(max(release, 0.005), 0.250))
    }
}
