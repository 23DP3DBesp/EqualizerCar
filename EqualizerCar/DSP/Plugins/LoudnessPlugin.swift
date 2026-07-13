import AVFoundation

@MainActor
final class LoudnessPlugin: AudioEffectPlugin {
    let displayName = "Loudness"
    let eqNode = AVAudioUnitEQ(numberOfBands: 2)

    var node: AVAudioNode { eqNode }

    var isEnabled: Bool = false {
        didSet {
            applyState()
        }
    }

    init() {
        let lowBand = eqNode.bands[0]
        lowBand.filterType = .lowShelf
        lowBand.frequency = 90
        lowBand.bandwidth = 0.7
        lowBand.bypass = false

        let highBand = eqNode.bands[1]
        highBand.filterType = .highShelf
        highBand.frequency = 8_000
        highBand.bandwidth = 0.7
        highBand.bypass = false

        applyState()
    }

    private func applyState() {
        eqNode.bands[0].gain = isEnabled ? 5 : 0
        eqNode.bands[1].gain = isEnabled ? 3 : 0
    }
}
