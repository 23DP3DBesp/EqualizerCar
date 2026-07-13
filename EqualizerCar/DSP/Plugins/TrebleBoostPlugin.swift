import AVFoundation

@MainActor
final class TrebleBoostPlugin: AudioEffectPlugin {
    let displayName = "Treble Boost"
    let eqNode = AVAudioUnitEQ(numberOfBands: 1)

    var node: AVAudioNode { eqNode }

    var isEnabled: Bool = false {
        didSet {
            eqNode.bands.first?.gain = isEnabled ? 6 : 0
        }
    }

    init() {
        if let band = eqNode.bands.first {
            band.filterType = .highShelf
            band.frequency = 6_500
            band.gain = 0
            band.bypass = false
        }
    }
}
