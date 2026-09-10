import Accelerate
import AVFoundation

@MainActor
final class VirtualSubwooferPlugin: AudioEffectPlugin {
    let displayName = "Virtual Subwoofer"
    let distortionNode = AVAudioUnitDistortion()

    var node: AVAudioNode { distortionNode }

    var isEnabled: Bool = false {
        didSet { applyState() }
    }

    var cutoffFrequency: Float = 55 {
        didSet { applyState() }
    }

    var mix: Float = 0 {
        didSet { applyState() }
    }

    init() {
        distortionNode.loadFactoryPreset(.multiDistortedSquared)
        distortionNode.preGain = -32
        distortionNode.wetDryMix = 0
    }

    private func applyState() {
        let clampedMix = Self.clamp(mix, 0, 1)
        let clampedCutoff = Self.clamp(cutoffFrequency, 30, 70)
        distortionNode.preGain = -34 + (clampedCutoff - 30) / 40 * 6 + clampedMix * 8
        distortionNode.wetDryMix = isEnabled ? clampedMix * 38 : 0
    }

    nonisolated static func synthesizeMissingFundamental(
        samples: [Float],
        sampleRate: Double,
        cutoffFrequency: Float = 55,
        mix: Float
    ) -> [Float] {
        guard !samples.isEmpty, sampleRate > 0 else { return samples }
        let clampedMix = clamp(mix, 0, 1)
        guard clampedMix > 0 else { return samples }

        let clampedCutoff = clamp(cutoffFrequency, 30, 70)
        let sourceBand = onePoleLowPass(samples: samples, cutoffFrequency: clampedCutoff, sampleRate: Float(sampleRate))
        var secondOrder = [Float](repeating: 0, count: samples.count)
        var thirdOrder = [Float](repeating: 0, count: samples.count)
        var shapedThirdOrder = [Float](repeating: 0, count: samples.count)
        var harmonics = [Float](repeating: 0, count: samples.count)
        var scaledHarmonics = [Float](repeating: 0, count: samples.count)
        var result = [Float](repeating: 0, count: samples.count)

        vDSP.absolute(sourceBand, result: &secondOrder)
        vDSP.multiply(sourceBand, sourceBand, result: &thirdOrder)
        vDSP.multiply(thirdOrder, sourceBand, result: &thirdOrder)
        vDSP.multiply(-1.0 / 3.0, thirdOrder, result: &shapedThirdOrder)
        vDSP.add(sourceBand, shapedThirdOrder, result: &thirdOrder)
        vDSP.multiply(0.62, secondOrder, result: &secondOrder)
        vDSP.multiply(0.38, thirdOrder, result: &thirdOrder)
        vDSP.add(secondOrder, thirdOrder, result: &harmonics)

        let bandPassed = onePoleHighPass(
            samples: onePoleLowPass(
                samples: onePoleLowPass(samples: harmonics, cutoffFrequency: 160, sampleRate: Float(sampleRate)),
                cutoffFrequency: 160,
                sampleRate: Float(sampleRate)
            ),
            cutoffFrequency: max(60, clampedCutoff * 2),
            sampleRate: Float(sampleRate)
        )

        vDSP.multiply(clampedMix, bandPassed, result: &scaledHarmonics)
        vDSP.add(samples, scaledHarmonics, result: &result)
        vDSP.clip(result, to: -1...1, result: &result)
        return result
    }

    private nonisolated static func clamp(_ value: Float, _ lowerBound: Float, _ upperBound: Float) -> Float {
        min(max(value, lowerBound), upperBound)
    }

    private nonisolated static func onePoleLowPass(samples: [Float], cutoffFrequency: Float, sampleRate: Float) -> [Float] {
        guard !samples.isEmpty else { return [] }
        let dt = 1 / sampleRate
        let rc = 1 / (2 * Float.pi * cutoffFrequency)
        let alpha = dt / (rc + dt)
        var output = [Float](repeating: 0, count: samples.count)
        output[0] = samples[0]
        for index in samples.indices.dropFirst() {
            output[index] = output[index - 1] + alpha * (samples[index] - output[index - 1])
        }
        return output
    }

    private nonisolated static func onePoleHighPass(samples: [Float], cutoffFrequency: Float, sampleRate: Float) -> [Float] {
        guard !samples.isEmpty else { return [] }
        let dt = 1 / sampleRate
        let rc = 1 / (2 * Float.pi * cutoffFrequency)
        let alpha = rc / (rc + dt)
        var output = [Float](repeating: 0, count: samples.count)
        output[0] = samples[0]
        for index in samples.indices.dropFirst() {
            output[index] = alpha * (output[index - 1] + samples[index] - samples[index - 1])
        }
        return output
    }
}
