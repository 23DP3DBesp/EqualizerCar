import AVFoundation
import AudioToolbox

@MainActor
final class LimiterPlugin: AudioEffectPlugin {
    let displayName = "Limiter"
    let effectNode = AudioUnitEffectFactory.makeAppleEffect(subType: kAudioUnitSubType_PeakLimiter)

    var node: AVAudioNode { effectNode }

    var isEnabled: Bool = true {
        didSet {
            effectNode.auAudioUnit.shouldBypassEffect = !isEnabled
        }
    }

    var ceiling: Float = -1 {
        didSet { applyParameters() }
    }

    var release: Float = 0.08 {
        didSet { applyParameters() }
    }

    init() {
        effectNode.auAudioUnit.shouldBypassEffect = false
        applyParameters()
    }

    private func applyParameters() {
        AudioUnitParameterWriter.set(effectNode, candidates: ["ceiling", "limit", "threshold"], value: ceiling)
        AudioUnitParameterWriter.set(effectNode, candidates: ["release", "releasetime", "decay"], value: release)
    }
}
