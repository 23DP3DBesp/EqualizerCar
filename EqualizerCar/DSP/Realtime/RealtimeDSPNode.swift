import AVFoundation

/// Indices match ec::Mode in DSPKernel.hpp; direct numeric parameter addresses never rely on AU display names.
@MainActor
final class RealtimeDSPNode {
    enum Mode: UInt32 {
        case bass, treble, loudness, gain, compressor, limiter, multiband, softClip,
             width, spatial, surround, reverb, virtualSub, exciter, phase, notch,
             hum, crossover, stereo3D, saturation, transient, collapse, bassMono, subsonic, vocalClarity, nightMode
    }
    let audioUnit: AVAudioUnitEffect
    private let processor: ECProcessingAudioUnit
    var node: AVAudioNode { audioUnit }

    init(_ mode: Mode) {
        ECProcessingAudioUnit.registerComponents()
        let description = AudioComponentDescription(componentType: kAudioUnitType_Effect,
            componentSubType: 0x45630000 + mode.rawValue, componentManufacturer: 0x45714372,
            componentFlags: 0, componentFlagsMask: 0)
        audioUnit = AVAudioUnitEffect(audioComponentDescription: description)
        guard let unit = audioUnit.auAudioUnit as? ECProcessingAudioUnit else {
            preconditionFailure("EqualizerCar DSP component registration failed")
        }
        processor = unit
    }
    func set(_ index: Int, _ value: Float) {
        processor.setDSPParameter(UInt(index), value: value.isFinite ? value : 0)
    }
    func enable(_ enabled: Bool) { set(0, enabled ? 1 : 0) }
}
