import AVFoundation

@MainActor
final class BassBoostPlugin: AudioEffectPlugin {
    let displayName = "Bass Boost"
    let eqNode = AVAudioUnitEQ(numberOfBands: 1)

    var node: AVAudioNode { eqNode }

    var isEnabled: Bool = false {
        didSet { updateGain() }
    }

    // intensity in dB (0...12)
    var intensity: Float = 8 {
        didSet { updateGain() }
    }

    // frequency for low-shelf (40...150 Hz)
    var frequency: Float = 80 {
        didSet {
            if let band = eqNode.bands.first {
                band.frequency = frequency
            }
        }
    }

    init() {
        if let band = eqNode.bands.first {
            band.filterType = .lowShelf
            band.frequency = frequency
            band.gain = 0
            band.bypass = false
        }
    }

    private func updateGain() {
        let gain = isEnabled ? intensity : 0
        eqNode.bands.first?.gain = gain
    }
}
