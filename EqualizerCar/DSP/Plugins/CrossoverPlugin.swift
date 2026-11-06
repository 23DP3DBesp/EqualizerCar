import AVFoundation

enum CrossoverMode: String, Codable, Sendable { case subwoofer, speakers }

@MainActor
final class CrossoverPlugin: AudioEffectPlugin {
    let displayName = "Crossover"
    private let processor = RealtimeDSPNode(.crossover)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var crossoverFrequency: Float = 80 { didSet { processor.set(1, crossoverFrequency) } }
    var mode: CrossoverMode = .subwoofer { didSet { processor.set(2, mode == .speakers ? 1 : 0) } }
    init() { processor.set(1, crossoverFrequency) }
}
