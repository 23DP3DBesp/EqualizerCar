import AVFoundation

@MainActor
final class AUXSignalBoostPlugin: AudioEffectPlugin {
    private enum Constants {
        static let minimumGainDB: Float = 0
        static let maximumGainDB: Float = 12
    }

    let displayName = "AUX Signal Boost"
    let eqNode = AVAudioUnitEQ(numberOfBands: 1)

    var node: AVAudioNode { eqNode }

    var isEnabled: Bool = false {
        didSet { applyState() }
    }

    var gainDB: Float = 0 {
        didSet { applyState() }
    }

    init() {
        if let band = eqNode.bands.first {
            band.filterType = .parametric
            band.frequency = 1_000
            band.bandwidth = 1
            band.bypass = true
        }
        eqNode.globalGain = 0
    }

    private func applyState() {
        eqNode.globalGain = isEnabled ? min(max(gainDB, Constants.minimumGainDB), Constants.maximumGainDB) : 0
    }
}
