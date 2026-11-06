import AVFoundation

@MainActor
final class GroundLoopNoiseSuppressorPlugin: AudioEffectPlugin {
    let displayName = "Hum Notches"
    private let processor = RealtimeDSPNode(.hum)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var humFrequency: Float = 50 { didSet { processor.set(1, humFrequency) } }
    var enginePitchFrequency: Float = 120 { didSet { processor.set(2, enginePitchFrequency) } }
    var enginePitchTrackingEnabled = false { didSet { processor.set(3, enginePitchTrackingEnabled ? 1 : 0) } }
    init() { processor.set(1, humFrequency); processor.set(2, enginePitchFrequency) }
}
