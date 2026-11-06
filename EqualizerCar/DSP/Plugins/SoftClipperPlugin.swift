import AVFoundation

@MainActor
final class SoftClipperPlugin: AudioEffectPlugin {
    let displayName = "Soft Clipper"
    private let processor = RealtimeDSPNode(.softClip)
    var node: AVAudioNode { processor.node }
    var isEnabled = false { didSet { processor.enable(isEnabled) } }
    var drive: Float = 0.35 { didSet { processor.set(1, drive) } }

    init() {
        processor.set(1, drive)
        processor.enable(isEnabled)
    }
}
