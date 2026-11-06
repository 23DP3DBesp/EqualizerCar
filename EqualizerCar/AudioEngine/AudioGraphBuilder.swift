import AVFoundation

@MainActor
struct AudioGraphBuilder {
    // Keep both buses of every custom DSP unit in the same stereo format.
    // Mixers convert file and hardware formats at the edges of the chain.
    static let processingFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
    struct Chain {
        let inputGainNode: AVAudioMixerNode
        let environmentNode: AVAudioEnvironmentNode
        let outputGainNode: AVAudioMixerNode
    }

    static func build(
        engine: AVAudioEngine,
        playerNode: AVAudioPlayerNode,
        eqNode: AVAudioUnitEQ,
        preEQNodes: [AVAudioNode] = [],
        toneAndDynamicsNodes: [AVAudioNode],
        reverbNode: AVAudioNode,
        finalProtectionNode: AVAudioNode? = nil,
        finalProcessingNodes: [AVAudioNode] = []
    ) -> Chain {
        let inputGainNode = AVAudioMixerNode()
        let environmentNode = AVAudioEnvironmentNode()
        let outputGainNode = AVAudioMixerNode()

        let finalNodes = finalProcessingNodes + [finalProtectionNode].compactMap { $0 }
        let nodes = [playerNode, inputGainNode] + preEQNodes + [eqNode] + toneAndDynamicsNodes + [reverbNode, environmentNode, outputGainNode] + finalNodes
        nodes.forEach { engine.attach($0) }

        var previous: AVAudioNode = playerNode
        for node in [inputGainNode] + preEQNodes + [eqNode] + toneAndDynamicsNodes + [reverbNode, environmentNode, outputGainNode] + finalNodes {
            engine.connect(previous, to: node, format: processingFormat)
            previous = node
        }
        engine.connect(previous, to: engine.mainMixerNode, format: processingFormat)

        configureDefaultGainStaging(inputGainNode: inputGainNode, outputGainNode: outputGainNode)
        configureEnvironment(
            environmentNode,
            spatialEnabled: false,
            depth: 0,
            surroundEnabled: false,
            surroundAmount: 0,
            eightDEnabled: false,
            eightDIntensity: 0
        )

        return Chain(
            inputGainNode: inputGainNode,
            environmentNode: environmentNode,
            outputGainNode: outputGainNode
        )
    }

    static func configureDefaultGainStaging(inputGainNode: AVAudioMixerNode, outputGainNode: AVAudioMixerNode) {
        inputGainNode.outputVolume = 1
        outputGainNode.outputVolume = 1
    }

    static func configureEnvironment(
        _ node: AVAudioEnvironmentNode,
        spatialEnabled: Bool,
        depth: Float,
        surroundEnabled: Bool,
        surroundAmount: Float,
        eightDEnabled: Bool,
        eightDIntensity: Float
    ) {
        // Spatial coloration is produced by the DSP nodes. 8D uses the output pan.
        // An environment is not a point-source input bus; configuring it as one did not spatialize stereo files.
        node.sourceMode = .bypass
        node.renderingAlgorithm = .stereoPassThrough
        node.reverbParameters.enable = false
        node.outputVolume = 1
    }
}
