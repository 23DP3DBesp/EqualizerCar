import Foundation

struct LegacyCarAudioProfile: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let bandCount: Int
    let gains: [Float]
    let filterTypes: [EQBandFilterType]
    let effects: PresetEffectSettings

    init(
        name: String,
        description: String,
        bandCount: Int = 5,
        gains: [Float],
        filterTypes: [EQBandFilterType] = Array(repeating: .parametric, count: 5),
        effects: PresetEffectSettings
    ) {
        self.id = name
        self.name = name
        self.description = description
        self.bandCount = bandCount
        self.gains = gains
        self.filterTypes = filterTypes
        self.effects = effects
    }

    var preset: Preset {
        let frequencies: [Float] = [60, 250, 1_000, 4_000, 12_000]
        let points = zip(zip(frequencies, gains), filterTypes).map { frequencyAndGain, filterType in
            PresetPoint(frequency: frequencyAndGain.0, gain: frequencyAndGain.1, filterType: filterType)
        }
        return Preset(name: name, points: points, effects: effects, isBuiltIn: true, category: .car)
    }

    static let all: [LegacyCarAudioProfile] = [
        LegacyCarAudioProfile(
            name: "W211 Audio 20 / APS 50 (AUX-Fix)",
            description: "Raises low AUX level, controls hum, keeps stereo stable, and protects the OEM input from clipping.",
            gains: [3, 1, 0, 2, 3],
            filterTypes: [.lowShelf, .parametric, .parametric, .highShelf, .highShelf],
            effects: PresetEffectSettings(
                bassBoostEnabled: true,
                trebleBoostEnabled: true,
                loudnessEnabled: true,
                compressorEnabled: true,
                compressorThreshold: -22,
                compressorRatio: 3.4,
                limiterEnabled: true,
                limiterCeiling: -1.5,
                inputGain: 0.78,
                outputGain: 0.86,
                volumeBoost: 1.12,
                auxSignalBoostEnabled: true,
                auxSignalBoostDB: 6,
                groundLoopSuppressorEnabled: true,
                groundLoopHumFrequency: 50,
                engineNoiseNotchEnabled: false,
                stereoCollapseEnabled: true,
                stereoCollapseWidth: 0.78,
                clipperProtectionEnabled: true
            )
        ),
        LegacyCarAudioProfile(
            name: "W211 Harman Kardon Logic 7 (AUX-Fix)",
            description: "Feeds a clean 2-channel AUX signal into OEM multi-speaker processing with center focus and controlled ambience.",
            gains: [2, 1, 0, 2, 2],
            filterTypes: [.lowShelf, .parametric, .parametric, .highShelf, .highShelf],
            effects: PresetEffectSettings(
                bassBoostEnabled: true,
                bassBoostIntensity: 4,
                bassBoostFrequency: 72,
                compressorEnabled: true,
                compressorThreshold: -20,
                compressorRatio: 2.8,
                limiterEnabled: true,
                limiterCeiling: -1.2,
                spatialAudioEnabled: true,
                spatialAudioDepth: 0.32,
                surroundEnabled: true,
                surroundAmount: 0.20,
                inputGain: 0.76,
                outputGain: 0.84,
                volumeBoost: 1.10,
                auxSignalBoostEnabled: true,
                auxSignalBoostDB: 4.5,
                groundLoopSuppressorEnabled: true,
                groundLoopHumFrequency: 50,
                stereoCollapseEnabled: true,
                stereoCollapseWidth: 0.88,
                clipperProtectionEnabled: true,
                logic7SpatializerEnabled: true,
                logic7Ambience: 0.42,
                logic7CenterFocus: 0.62
            )
        ),
        LegacyCarAudioProfile(
            name: "Generic FM Transmitter Clear Highs",
            description: "Adds controlled presence and harmonics for FM transmitters while avoiding harsh clipping.",
            gains: [1, -1, 0, 3, 5],
            filterTypes: [.parametric, .parametric, .parametric, .highShelf, .highShelf],
            effects: PresetEffectSettings(
                trebleBoostEnabled: true,
                loudnessEnabled: true,
                compressorEnabled: true,
                compressorThreshold: -24,
                compressorRatio: 3.8,
                limiterEnabled: true,
                limiterCeiling: -2,
                inputGain: 0.74,
                outputGain: 0.82,
                volumeBoost: 1.05,
                fmExciterEnabled: true,
                fmExciterIntensity: 0.42,
                stereoCollapseEnabled: true,
                stereoCollapseWidth: 0.62,
                clipperProtectionEnabled: true
            )
        )
    ]
}

struct FMFrequencyCandidate: Identifiable, Sendable {
    let id = UUID()
    let frequencyMHz: Float
    let label: String
    let note: String

    static let localCleanCandidates: [FMFrequencyCandidate] = [
        FMFrequencyCandidate(frequencyMHz: 87.6, label: "Low Band", note: "Often least crowded in dense EU cities."),
        FMFrequencyCandidate(frequencyMHz: 88.0, label: "Low Band", note: "Good first scan point for compact FM transmitters."),
        FMFrequencyCandidate(frequencyMHz: 88.3, label: "Low Band", note: "Try if 87.6-88.0 has spillover."),
        FMFrequencyCandidate(frequencyMHz: 107.5, label: "High Band", note: "Useful when low band is occupied."),
        FMFrequencyCandidate(frequencyMHz: 107.7, label: "High Band", note: "Common clear slot for short-range transmitters."),
        FMFrequencyCandidate(frequencyMHz: 107.9, label: "High Band", note: "Last-resort slot; scan for local stations first.")
    ]
}
