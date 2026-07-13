import AVFoundation
import AudioToolbox

@MainActor
final class CompressorPlugin: AudioEffectPlugin {
    let displayName = "Compressor"
    let effectNode = AudioUnitEffectFactory.makeAppleEffect(subType: kAudioUnitSubType_DynamicsProcessor)

    var node: AVAudioNode { effectNode }

    var isEnabled: Bool = false {
        didSet {
            effectNode.auAudioUnit.shouldBypassEffect = !isEnabled
        }
    }

    var threshold: Float = -18 {
        didSet { applyParameters() }
    }

    var ratio: Float = 3 {
        didSet { applyParameters() }
    }

    var attack: Float = 0.012 {
        didSet { applyParameters() }
    }

    var release: Float = 0.18 {
        didSet { applyParameters() }
    }

    init() {
        effectNode.auAudioUnit.shouldBypassEffect = true
        applyParameters()
    }

    private func applyParameters() {
        AudioUnitParameterWriter.set(effectNode, candidates: ["threshold", "thresh"], value: threshold)
        AudioUnitParameterWriter.set(effectNode, candidates: ["ratio"], value: ratio)
        AudioUnitParameterWriter.set(effectNode, candidates: ["attack", "attacktime"], value: attack)
        AudioUnitParameterWriter.set(effectNode, candidates: ["release", "releasetime"], value: release)
    }
}
