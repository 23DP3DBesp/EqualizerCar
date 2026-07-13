import AVFoundation

@MainActor
enum AudioUnitParameterWriter {
    static func set(_ node: AVAudioUnit, candidates: [String], value: Float) {
        guard let parameter = findParameter(in: node, candidates: candidates) else { return }
        parameter.value = min(max(value, parameter.minValue), parameter.maxValue)
    }

    private static func findParameter(in node: AVAudioUnit, candidates: [String]) -> AUParameter? {
        guard let allParameters = node.auAudioUnit.parameterTree?.allParameters else { return nil }
        let normalizedCandidates = candidates.map(normalized)

        return allParameters.first { parameter in
            let name = normalized(parameter.displayName)
            let identifier = normalized(parameter.identifier)
            return normalizedCandidates.contains { candidate in
                name.contains(candidate) || identifier.contains(candidate)
            }
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}
