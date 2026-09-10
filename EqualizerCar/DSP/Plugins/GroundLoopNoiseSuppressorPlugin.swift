import AVFoundation

@MainActor
final class GroundLoopNoiseSuppressorPlugin: AudioEffectPlugin {
    let displayName = "Ground Loop Suppressor"
    let eqNode = AVAudioUnitEQ(numberOfBands: 2)

    var node: AVAudioNode { eqNode }

    var isEnabled: Bool = false {
        didSet { applyState() }
    }

    var humFrequency: Float = 50 {
        didSet { applyState() }
    }

    var enginePitchFrequency: Float = 120 {
        didSet { applyState() }
    }

    var enginePitchTrackingEnabled: Bool = false {
        didSet { applyState() }
    }

    var attenuationDB: Float = -18 {
        didSet { applyState() }
    }

    init() {
        for band in eqNode.bands {
            band.filterType = .parametric
            band.bandwidth = 0.05
            band.gain = 0
            band.bypass = true
        }
        applyState()
    }

    private func applyState() {
        let hum = min(max(humFrequency, 45), 65)
        let pitch = min(max(enginePitchFrequency, 80), 420)
        let gain = min(max(attenuationDB, -36), 0)

        if eqNode.bands.indices.contains(0) {
            let band = eqNode.bands[0]
            band.filterType = .parametric
            band.frequency = hum
            band.bandwidth = 0.04
            band.gain = isEnabled ? gain : 0
            band.bypass = !isEnabled
        }

        if eqNode.bands.indices.contains(1) {
            let band = eqNode.bands[1]
            band.filterType = .parametric
            band.frequency = pitch
            band.bandwidth = 0.06
            band.gain = isEnabled && enginePitchTrackingEnabled ? gain * 0.65 : 0
            band.bypass = !isEnabled || !enginePitchTrackingEnabled
        }
    }
}
