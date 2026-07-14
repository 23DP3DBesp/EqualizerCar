import Foundation
import AVFoundation

final class MultibandCompressorPlugin {
    private let engine: AVAudioEngine

    // Band split: low, mid, high
    let lowEQ = AVAudioUnitEQ(numberOfBands: 1)
    let midEQ = AVAudioUnitEQ(numberOfBands: 1)
    let highEQ = AVAudioUnitEQ(numberOfBands: 1)

    let lowComp = AVAudioUnitDynamicsProcessor()
    let midComp = AVAudioUnitDynamicsProcessor()
    let highComp = AVAudioUnitDynamicsProcessor()

    let splitter = AVAudioMixerNode()
    let merger = AVAudioMixerNode()

    var isEnabled: Bool = false {
        didSet { updateBypass() }
    }

    // Shared parameters
    var lowThreshold: Float = -18 { didSet { lowComp.threshold = lowThreshold } }
    var lowRatio: Float = 3 { didSet { /* dynamics processor has ratio-like parameters via expansion; fine-tune later */ } }

    var midThreshold: Float = -18 { didSet { midComp.threshold = midThreshold } }
    var highThreshold: Float = -18 { didSet { highComp.threshold = highThreshold } }

    init(engine: AVAudioEngine) {
        self.engine = engine
        setupFilters()
    }

    func attach(to engine: AVAudioEngine) {
        engine.attach(lowEQ)
        engine.attach(midEQ)
        engine.attach(highEQ)
        engine.attach(lowComp)
        engine.attach(midComp)
        engine.attach(highComp)
    }

    private func setupFilters() {
        // Low band: lowpass at ~200 Hz
        let lowBand = lowEQ.bands[0]
        lowBand.filterType = .lowPass
        lowBand.frequency = 200
        lowBand.bypass = false

        let midBand = midEQ.bands[0]
        midBand.filterType = .bandPass
        midBand.frequency = 1000
        midBand.bandwidth = 1.0
        midBand.bypass = false

        let highBand = highEQ.bands[0]
        highBand.filterType = .highPass
        highBand.frequency = 5000
        highBand.bypass = false
    }

    func connect(input: AVAudioNode, to output: AVAudioNode) {
        // Basic connection: input -> splitter -> three filter chains -> merger -> output
        let mainMixer = engine.mainMixerNode

        engine.connect(input, to: splitter, format: nil)

        // splitter to each EQ
        engine.connect(splitter, to: lowEQ, format: nil)
        engine.connect(splitter, to: midEQ, format: nil)
        engine.connect(splitter, to: highEQ, format: nil)

        engine.connect(lowEQ, to: lowComp, format: nil)
        engine.connect(midEQ, to: midComp, format: nil)
        engine.connect(highEQ, to: highComp, format: nil)

        engine.connect(lowComp, to: merger, format: nil)
        engine.connect(midComp, to: merger, format: nil)
        engine.connect(highComp, to: merger, format: nil)

        engine.connect(merger, to: output, format: nil)
    }

    var inputNode: AVAudioNode { splitter }
    var outputNode: AVAudioNode { merger }

    func disconnect() {
        engine.disconnectNodeInput(lowEQ)
        engine.disconnectNodeInput(midEQ)
        engine.disconnectNodeInput(highEQ)
        engine.disconnectNodeOutput(lowComp)
        engine.disconnectNodeOutput(midComp)
        engine.disconnectNodeOutput(highComp)
        engine.disconnectNodeOutput(merger)
    }

    private func updateBypass() {
        lowEQ.bypass = !isEnabled
        midEQ.bypass = !isEnabled
        highEQ.bypass = !isEnabled
        lowComp.bypass = !isEnabled
        midComp.bypass = !isEnabled
        highComp.bypass = !isEnabled
    }
}
