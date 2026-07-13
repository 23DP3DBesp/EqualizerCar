import AVFoundation

@MainActor
final class BassBoostPlugin: AudioEffectPlugin {
    let displayName = "Bass Boost"
    let eqNode = AVAudioUnitEQ(numberOfBands: 1)

    var node: AVAudioNode { eqNode }

    var isEnabled: Bool = false {
        didSet {
            eqNode.bands.first?.gain = isEnabled ? 8 : 0
        }
    }

    init() {
        if let band = eqNode.bands.first {
            band.filterType = .lowShelf
            band.frequency = 80
            band.gain = 0
            band.bypass = false
        }
    }
}
