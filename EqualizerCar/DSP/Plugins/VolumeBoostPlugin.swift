import AVFoundation

@MainActor
final class VolumeBoostPlugin: AudioEffectPlugin {
    private enum Constants {
        static let minimumMultiplier: Float = 1
        static let maximumMultiplier: Float = 3
    }

    let displayName = "Volume Boost"
    let eqNode = AVAudioUnitEQ(numberOfBands: 1)

    var node: AVAudioNode { eqNode }

    var isEnabled: Bool = true {
        didSet {
            applyMultiplier()
        }
    }

    var multiplier: Float = Constants.minimumMultiplier {
        didSet {
            applyMultiplier()
        }
    }

    init() {
        if let band = eqNode.bands.first {
            band.filterType = .parametric
            band.frequency = 1_000
            band.bandwidth = 1
            band.gain = 0
            band.bypass = true
        }
        eqNode.globalGain = 0
    }

    private func applyMultiplier() {
        guard isEnabled else {
            eqNode.globalGain = 0
            return
        }

        let safeMultiplier = sanitizedMultiplier(multiplier)
        eqNode.globalGain = 20 * log10(safeMultiplier)
    }

    private func sanitizedMultiplier(_ value: Float) -> Float {
        guard value.isFinite else { return Constants.minimumMultiplier }
        return min(max(value, Constants.minimumMultiplier), Constants.maximumMultiplier)
    }
}
