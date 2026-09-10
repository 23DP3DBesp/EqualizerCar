import AVFoundation
import AudioToolbox

@MainActor
final class MultibandCompressorPlugin: AudioEffectPlugin {
    let displayName = "Multiband Compressor"
    let effectNode = AudioUnitEffectFactory.makeAppleEffect(subType: kAudioUnitSubType_DynamicsProcessor)

    var node: AVAudioNode { effectNode }

    var isEnabled: Bool = false {
        didSet {
            effectNode.auAudioUnit.shouldBypassEffect = !isEnabled
        }
    }

    init() {
        effectNode.auAudioUnit.shouldBypassEffect = true
        AudioUnitParameterWriter.set(effectNode, candidates: ["threshold", "thresh"], value: -20)
        AudioUnitParameterWriter.set(effectNode, candidates: ["ratio"], value: 2.5)
        AudioUnitParameterWriter.set(effectNode, candidates: ["attack", "attacktime"], value: 0.018)
        AudioUnitParameterWriter.set(effectNode, candidates: ["release", "releasetime"], value: 0.22)
    }
}
