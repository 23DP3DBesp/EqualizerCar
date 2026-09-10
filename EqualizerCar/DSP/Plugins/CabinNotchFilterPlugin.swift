import AVFoundation

@MainActor
final class CabinNotchFilterPlugin: AudioEffectPlugin {
    let displayName = "Cabin Resonance Notch"
    let eqNode = AVAudioUnitEQ(numberOfBands: 1)

    var node: AVAudioNode { eqNode }

    var isEnabled: Bool = false {
        didSet { applyState() }
    }

    var frequency: Float = 135 {
        didSet { applyState() }
    }

    var qFactor: Float = 6 {
        didSet { applyState() }
    }

    var gain: Float = -6 {
        didSet { applyState() }
    }

    init() {
        if let band = eqNode.bands.first {
            band.filterType = .parametric
            band.bypass = true
        }
        applyState()
    }

    private func applyState() {
        guard let band = eqNode.bands.first else { return }
        let clampedFrequency = min(max(frequency, 100), 200)
        let clampedQ = min(max(qFactor, 4), 8)
        let clampedGain = min(max(gain, -18), 0)

        band.filterType = .parametric
        band.frequency = clampedFrequency
        band.bandwidth = bandwidthOctaves(forQ: clampedQ)
        band.gain = isEnabled ? clampedGain : 0
        band.bypass = !isEnabled
    }

    private func bandwidthOctaves(forQ qFactor: Float) -> Float {
        // AVAudioUnitEQ uses octave bandwidth, while cabin correction is easier to tune as Q.
        let q = max(qFactor, 0.001)
        let qSquared = q * q
        let term = 2 * qSquared + 1
        let ratio = (term + sqrt(max(term * term - 1, 0))) / (2 * qSquared)
        return min(max(log2(ratio), 0.05), 0.35)
    }
}
