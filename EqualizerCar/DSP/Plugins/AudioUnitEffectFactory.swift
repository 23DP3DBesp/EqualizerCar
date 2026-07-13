import AVFoundation
import AudioToolbox

enum AudioUnitEffectFactory {
    static func makeAppleEffect(subType: OSType) -> AVAudioUnitEffect {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: subType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        return AVAudioUnitEffect(audioComponentDescription: description)
    }
}
