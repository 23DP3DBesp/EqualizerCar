import AVFoundation

@MainActor
protocol AudioEffectPlugin: AnyObject {
    var displayName: String { get }
    var node: AVAudioNode { get }
    var isEnabled: Bool { get set }
}
