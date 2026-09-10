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

    static func makeAppleUnit(componentType: OSType, subType: OSType) -> AVAudioUnit {
        let description = AudioComponentDescription(
            componentType: componentType,
            componentSubType: subType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let semaphore = DispatchSemaphore(value: 0)
        var instantiatedUnit: AVAudioUnit?

        AVAudioUnit.instantiate(with: description, options: []) { audioUnit, _ in
            instantiatedUnit = audioUnit
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1)

        return instantiatedUnit ?? AVAudioUnitEQ(numberOfBands: 0)
    }
}
