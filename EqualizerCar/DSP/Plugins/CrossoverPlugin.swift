import AVFoundation

enum CrossoverMode: String, Codable, Sendable {
    case subwoofer
    case speakers
}

@MainActor
final class CrossoverPlugin: AudioEffectPlugin {
    let displayName = "Crossover"
    let eqNode = AVAudioUnitEQ(numberOfBands: 1)

    var node: AVAudioNode { eqNode }

    var isEnabled: Bool = false {
        didSet { eqNode.bands.first?.bypass = !isEnabled }
    }

    var crossoverFrequency: Float = 80 {
        didSet { eqNode.bands.first?.frequency = crossoverFrequency }
    }

    var mode: CrossoverMode = .subwoofer {
        didSet { applyMode() }
    }

    init() {
        if let band = eqNode.bands.first {
            band.filterType = .lowPass
            band.frequency = crossoverFrequency
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = true
        }
        applyMode()
    }

    private func applyMode() {
        guard let band = eqNode.bands.first else { return }
        switch mode {
        case .subwoofer:
            band.filterType = .lowPass
        case .speakers:
            band.filterType = .highPass
        }
        band.frequency = crossoverFrequency
    }
}
