import AVFoundation

@MainActor
struct AudioGraphBuilder {
    struct Chain {
        let inputGainNode: AVAudioMixerNode
        let environmentNode: AVAudioEnvironmentNode
        let outputGainNode: AVAudioMixerNode
    }

    static func build(
        engine: AVAudioEngine,
        playerNode: AVAudioPlayerNode,
        eqNode: AVAudioUnitEQ,
        toneAndDynamicsNodes: [AVAudioNode],
        reverbNode: AVAudioNode
    ) -> Chain {
        let inputGainNode = AVAudioMixerNode()
        let environmentNode = AVAudioEnvironmentNode()
        let outputGainNode = AVAudioMixerNode()

        let nodes = [playerNode, inputGainNode, eqNode] + toneAndDynamicsNodes + [reverbNode, environmentNode, outputGainNode]
        nodes.forEach { engine.attach($0) }

        var previous: AVAudioNode = playerNode
        for node in [inputGainNode, eqNode] + toneAndDynamicsNodes + [reverbNode, environmentNode, outputGainNode] {
            engine.connect(previous, to: node, format: nil)
            previous = node
        }
        engine.connect(outputGainNode, to: engine.mainMixerNode, format: nil)

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
        inputGainNode.outputVolume = 0.82
        outputGainNode.outputVolume = 0.90
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
        let clampedDepth = min(max(depth, 0), 1)
        let clampedSurround = min(max(surroundAmount, 0), 1)
        let clampedEightD = min(max(eightDIntensity, 0), 1)
        let usesSpatialRenderer = spatialEnabled || eightDEnabled

        node.outputType = .auto
        node.listenerPosition = AVAudioMake3DPoint(0, 0, 0)
        node.listenerAngularOrientation = AVAudioMake3DAngularOrientation(0, 0, 0)
        if eightDEnabled {
            node.position = AVAudioMake3DPoint(0, 0, -1.3 - clampedEightD * 2.1)
        } else {
            node.position = spatialEnabled ? AVAudioMake3DPoint(clampedDepth * 2.4, 0, -1.5 - clampedDepth * 1.8) : AVAudioMake3DPoint(0, 0, 0)
        }
        node.sourceMode = usesSpatialRenderer ? .pointSource : .bypass
        node.renderingAlgorithm = usesSpatialRenderer ? .HRTFHQ : .stereoPassThrough
        node.reverbBlend = surroundEnabled ? clampedSurround : 0
        node.reverbParameters.enable = surroundEnabled
        node.reverbParameters.level = surroundEnabled ? (-18 + clampedSurround * 18) : -120
        node.reverbParameters.loadFactoryReverbPreset(.largeHall)
        node.outputVolume = 1
    }
}
