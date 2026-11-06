import AVFoundation

@MainActor
final class AUXSignalBoostPlugin: AudioEffectPlugin {
    let displayName = "AUX Signal Boost"
    private let processor = RealtimeDSPNode(.gain)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var gainDB: Float = 3 { didSet { processor.set(1, min(max(gainDB, 0), 12)) } }

    init() {
        processor.set(1, min(max(gainDB, 0), 12))
        processor.enable(isEnabled)
    }
}
