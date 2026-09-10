import Accelerate
import AVFoundation

@MainActor
final class FMDynamicExciterPlugin: AudioEffectPlugin {
    let displayName = "FM Dynamic Exciter"
    let distortionNode = AVAudioUnitDistortion()

    var node: AVAudioNode { distortionNode }

    var isEnabled: Bool = false {
        didSet { applyState() }
    }

    var intensity: Float = 0.35 {
        didSet { applyState() }
    }

    init() {
        distortionNode.loadFactoryPreset(.multiDistortedSquared)
        distortionNode.preGain = -24
        distortionNode.wetDryMix = 0
    }

    private func applyState() {
        let clamped = min(max(intensity, 0), 1)
        distortionNode.preGain = -24 + clamped * 8
        distortionNode.wetDryMix = isEnabled ? min(max(clamped * 14, 0), 14) : 0
    }

    nonisolated static func harmonicPreviewCurve(samples: [Float], intensity: Float) -> [Float] {
        guard !samples.isEmpty else { return [] }
        let clamped = min(max(intensity, 0), 1)
        let upperMix = clamped * 0.14
        let lowerMix = clamped * 0.06

        var rectified = [Float](repeating: 0, count: samples.count)
        var squared = [Float](repeating: 0, count: samples.count)
        var upper = [Float](repeating: 0, count: samples.count)
        var lower = [Float](repeating: 0, count: samples.count)
        var result = [Float](repeating: 0, count: samples.count)

        vDSP.absolute(samples, result: &rectified)
        vDSP.multiply(samples, rectified, result: &squared)
        vDSP.multiply(upperMix, squared, result: &upper)

        for index in samples.indices {
            let previous = index > 0 ? rectified[index - 1] : rectified[index]
            lower[index] = (previous + rectified[index]) * 0.5 * lowerMix
        }

        vDSP.add(samples, upper, result: &result)
        vDSP.add(result, lower, result: &result)
        vDSP.clip(result, to: -1...1, result: &result)
        return result
    }
}
