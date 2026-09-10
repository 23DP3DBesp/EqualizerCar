//
//  Preset.swift
//  EqualizerCar
//
//  Created by Денис Беспалов on 08/07/2026.
//

import Foundation
/// Пресет эквалайзера хранится как набор точек (частота, gain),
/// а не как фиксированный массив gain-значений — это позволяет
/// применять один и тот же пресет независимо от того, сколько сейчас
/// полос выбрано (5, 10 или 20): при применении берём ближайшую
/// по частоте точку пресета для каждой текущей полосы. Параметры эффектов
/// хранятся рядом, чтобы пресет описывал полную DSP-сцену.
struct Preset: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var points: [PresetPoint]
    var effects: PresetEffectSettings
    var isBuiltIn: Bool
    var category: PresetCategory
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        points: [PresetPoint],
        effects: PresetEffectSettings = PresetEffectSettings(),
        isBuiltIn: Bool = false,
        category: PresetCategory = .custom,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.points = points
        self.effects = effects
        self.isBuiltIn = isBuiltIn
        self.category = category
        self.isFavorite = isFavorite
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case points
        case effects
        case isBuiltIn
        case category
        case isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        points = try container.decode([PresetPoint].self, forKey: .points)
        effects = try container.decodeIfPresent(PresetEffectSettings.self, forKey: .effects) ?? PresetEffectSettings()
        isBuiltIn = try container.decode(Bool.self, forKey: .isBuiltIn)
        category = try container.decodeIfPresent(PresetCategory.self, forKey: .category) ?? .custom
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

enum PresetCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case bass = "Bass"
    case vocal = "Vocal"
    case car = "Car"
    case headphones = "Headphones"
    case eightD = "8D"
    case cinema = "Cinema"
    case loud = "Loud"
    case custom = "Custom"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "square.grid.2x2.fill"
        case .bass:
            return "speaker.wave.3.fill"
        case .vocal:
            return "mic.fill"
        case .car:
            return "car.fill"
        case .headphones:
            return "headphones"
        case .eightD:
            return "circle.grid.cross"
        case .cinema:
            return "theatermasks.fill"
        case .loud:
            return "bolt.fill"
        case .custom:
            return "slider.horizontal.3"
        }
    }
}

struct PresetPoint: Codable, Equatable, Sendable {
    let frequency: Float
    let gain: Float
    var filterType: EQBandFilterType = .parametric

    private enum CodingKeys: String, CodingKey {
        case frequency
        case gain
        case filterType
    }

    init(frequency: Float, gain: Float, filterType: EQBandFilterType = .parametric) {
        self.frequency = frequency
        self.gain = gain
        self.filterType = filterType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try container.decode(Float.self, forKey: .frequency)
        gain = try container.decode(Float.self, forKey: .gain)
        filterType = try container.decodeIfPresent(EQBandFilterType.self, forKey: .filterType) ?? .parametric
    }
}

enum EQBandFilterType: String, Codable, CaseIterable, Identifiable, Sendable {
    case parametric = "Parametric"
    case lowShelf = "Low Shelf"
    case highShelf = "High Shelf"
    case notch = "Notch"
    case highPass = "High-pass"
    case lowPass = "Low-pass"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .parametric:
            return "slider.horizontal.3"
        case .lowShelf:
            return "chart.line.uptrend.xyaxis"
        case .highShelf:
            return "chart.line.uptrend.xyaxis"
        case .notch:
            return "waveform.path.ecg"
        case .highPass:
            return "arrow.up.right"
        case .lowPass:
            return "arrow.down.right"
        }
    }
}

enum EightDAudioMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case beatReactive = "Beat Reactive"
    case vocalCenter = "Vocal Center"
    case bassOrbit = "Bass Orbit"
    case wideAir = "Wide Air"

    var id: String { rawValue }
}

enum SmartLoudBassMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case clean = "Clean"
    case loud = "Loud"
    case bassHeavy = "Bass Heavy"
    case max = "Max"

    var id: String { rawValue }
}

struct PresetEffectSettings: Codable, Equatable, Sendable {
    var bassBoostEnabled: Bool = false
    var trebleBoostEnabled: Bool = false
    var loudnessEnabled: Bool = false
    var bassBoostIntensity: Float = 8
    var bassBoostFrequency: Float = 80
    var virtualSubwooferEnabled: Bool = false
    var virtualSubwooferMix: Float = 0
    var virtualSubwooferCutoff: Float = 55
    var cabinNotchEnabled: Bool = false
    var cabinNotchFrequency: Float = 135
    var cabinNotchQ: Float = 6
    var cabinNotchGain: Float = -6
    var compressorEnabled: Bool = false
    var compressorThreshold: Float = -18
    var compressorRatio: Float = 3
    var compressorAttack: Float = 0.012
    var compressorRelease: Float = 0.18
    var limiterEnabled: Bool = true
    var limiterCeiling: Float = -1
    var limiterRelease: Float = 0.08
    var stereoWideningEnabled: Bool = false
    var stereoWideningIntensity: Float = 0.75
    var spatialAudioEnabled: Bool = false
    var spatialAudioDepth: Float = 0.65
    var surroundEnabled: Bool = false
    var surroundAmount: Float = 0.55
    var eightDAudioEnabled: Bool = false
    var eightDAudioIntensity: Float = 0.75
    var eightDAudioSpeed: Float = 0.30
    var eightDAudioMode: EightDAudioMode = .beatReactive
    var softClipperEnabled: Bool = false
    var reverbAmount: Float = 0
    var reverbSize: Float = 0.45
    var reverbDamping: Float = 0.35
    var inputGain: Float = 0.82
    var outputGain: Float = 0.90
    var volumeBoost: Float = 1
    var auxSignalBoostEnabled: Bool = false
    var auxSignalBoostDB: Float = 0
    var fmExciterEnabled: Bool = false
    var fmExciterIntensity: Float = 0.35
    var groundLoopSuppressorEnabled: Bool = false
    var groundLoopHumFrequency: Float = 50
    var engineNoiseNotchEnabled: Bool = false
    var engineNoiseFrequency: Float = 120
    var stereoCollapseEnabled: Bool = false
    var stereoCollapseWidth: Float = 1
    var clipperProtectionEnabled: Bool = true
    var logic7SpatializerEnabled: Bool = false
    var logic7Ambience: Float = 0.35
    var logic7CenterFocus: Float = 0.45
    var multibandCompressorEnabled: Bool = false
    var adaptiveBassBoostEnabled: Bool = false
    var crossoverEnabled: Bool = false
    var crossoverFrequency: Float = 80
    var crossoverMode: CrossoverMode = .subwoofer
    var subwooferPhaseInverted: Bool = false
    var smartLoudBassMode: SmartLoudBassMode = .clean
    var subBassGain: Float = 0
    var punchBassGain: Float = 0
    var warmthGain: Float = 0
    var bassTightness: Float = 0.5
    var subwooferModeEnabled: Bool = false
    var bassMonoBelow100Enabled: Bool = false

    private enum CodingKeys: String, CodingKey {
        case bassBoostEnabled
        case trebleBoostEnabled
        case loudnessEnabled
        case compressorEnabled
        case compressorThreshold
        case compressorRatio
        case compressorAttack
        case compressorRelease
        case limiterEnabled
        case limiterCeiling
        case limiterRelease
        case stereoWideningEnabled
        case stereoWideningIntensity
        case spatialAudioEnabled
        case spatialAudioDepth
        case surroundEnabled
        case surroundAmount
        case eightDAudioEnabled
        case eightDAudioIntensity
        case eightDAudioSpeed
        case eightDAudioMode
        case softClipperEnabled
        case reverbAmount
        case reverbSize
        case reverbDamping
        case inputGain
        case outputGain
        case volumeBoost
        case auxSignalBoostEnabled
        case auxSignalBoostDB
        case fmExciterEnabled
        case fmExciterIntensity
        case groundLoopSuppressorEnabled
        case groundLoopHumFrequency
        case engineNoiseNotchEnabled
        case engineNoiseFrequency
        case stereoCollapseEnabled
        case stereoCollapseWidth
        case clipperProtectionEnabled
        case logic7SpatializerEnabled
        case logic7Ambience
        case logic7CenterFocus
        case bassBoostIntensity
        case bassBoostFrequency
        case virtualSubwooferEnabled
        case virtualSubwooferMix
        case virtualSubwooferCutoff
        case cabinNotchEnabled
        case cabinNotchFrequency
        case cabinNotchQ
        case cabinNotchGain
        case adaptiveBassBoostEnabled
        case multibandCompressorEnabled
        case crossoverEnabled
        case crossoverFrequency
        case crossoverMode
        case subwooferPhaseInverted
        case smartLoudBassMode
        case subBassGain
        case punchBassGain
        case warmthGain
        case bassTightness
        case subwooferModeEnabled
        case bassMonoBelow100Enabled
    }

    nonisolated init(
        bassBoostEnabled: Bool = false,
        trebleBoostEnabled: Bool = false,
        loudnessEnabled: Bool = false,
        bassBoostIntensity: Float = 8,
        bassBoostFrequency: Float = 80,
        virtualSubwooferEnabled: Bool = false,
        virtualSubwooferMix: Float = 0,
        virtualSubwooferCutoff: Float = 55,
        cabinNotchEnabled: Bool = false,
        cabinNotchFrequency: Float = 135,
        cabinNotchQ: Float = 6,
        cabinNotchGain: Float = -6,
        compressorEnabled: Bool = false,
        compressorThreshold: Float = -18,
        compressorRatio: Float = 3,
        compressorAttack: Float = 0.012,
        compressorRelease: Float = 0.18,
        limiterEnabled: Bool = true,
        limiterCeiling: Float = -1,
        limiterRelease: Float = 0.08,
        stereoWideningEnabled: Bool = false,
        stereoWideningIntensity: Float = 0.75,
        spatialAudioEnabled: Bool = false,
        spatialAudioDepth: Float = 0.65,
        surroundEnabled: Bool = false,
        surroundAmount: Float = 0.55,
        eightDAudioEnabled: Bool = false,
        eightDAudioIntensity: Float = 0.75,
        eightDAudioSpeed: Float = 0.30,
        eightDAudioMode: EightDAudioMode = .beatReactive,
        softClipperEnabled: Bool = false,
        reverbAmount: Float = 0,
        reverbSize: Float = 0.45,
        reverbDamping: Float = 0.35,
        inputGain: Float = 0.82,
        outputGain: Float = 0.90,
        volumeBoost: Float = 1,
        auxSignalBoostEnabled: Bool = false,
        auxSignalBoostDB: Float = 0,
        fmExciterEnabled: Bool = false,
        fmExciterIntensity: Float = 0.35,
        groundLoopSuppressorEnabled: Bool = false,
        groundLoopHumFrequency: Float = 50,
        engineNoiseNotchEnabled: Bool = false,
        engineNoiseFrequency: Float = 120,
        stereoCollapseEnabled: Bool = false,
        stereoCollapseWidth: Float = 1,
        clipperProtectionEnabled: Bool = true,
        logic7SpatializerEnabled: Bool = false,
        logic7Ambience: Float = 0.35,
        logic7CenterFocus: Float = 0.45,
        multibandCompressorEnabled: Bool = false,
        adaptiveBassBoostEnabled: Bool = false,
        crossoverEnabled: Bool = false,
        crossoverFrequency: Float = 80,
        crossoverMode: CrossoverMode = .subwoofer,
        subwooferPhaseInverted: Bool = false,
        smartLoudBassMode: SmartLoudBassMode = .clean,
        subBassGain: Float = 0,
        punchBassGain: Float = 0,
        warmthGain: Float = 0,
        bassTightness: Float = 0.5,
        subwooferModeEnabled: Bool = false,
        bassMonoBelow100Enabled: Bool = false
    ) {
        self.bassBoostIntensity = bassBoostIntensity
        self.bassBoostFrequency = bassBoostFrequency
        self.bassBoostEnabled = bassBoostEnabled
        self.trebleBoostEnabled = trebleBoostEnabled
        self.loudnessEnabled = loudnessEnabled
        self.virtualSubwooferEnabled = virtualSubwooferEnabled
        self.virtualSubwooferMix = virtualSubwooferMix
        self.virtualSubwooferCutoff = virtualSubwooferCutoff
        self.cabinNotchEnabled = cabinNotchEnabled
        self.cabinNotchFrequency = cabinNotchFrequency
        self.cabinNotchQ = cabinNotchQ
        self.cabinNotchGain = cabinNotchGain
        self.compressorEnabled = compressorEnabled
        self.compressorThreshold = compressorThreshold
        self.compressorRatio = compressorRatio
        self.compressorAttack = compressorAttack
        self.compressorRelease = compressorRelease
        self.limiterEnabled = limiterEnabled
        self.limiterCeiling = limiterCeiling
        self.limiterRelease = limiterRelease
        self.stereoWideningEnabled = stereoWideningEnabled
        self.stereoWideningIntensity = stereoWideningIntensity
        self.spatialAudioEnabled = spatialAudioEnabled
        self.spatialAudioDepth = spatialAudioDepth
        self.surroundEnabled = surroundEnabled
        self.surroundAmount = surroundAmount
        self.eightDAudioEnabled = eightDAudioEnabled
        self.eightDAudioIntensity = eightDAudioIntensity
        self.eightDAudioSpeed = eightDAudioSpeed
        self.eightDAudioMode = eightDAudioMode
        self.softClipperEnabled = softClipperEnabled
        self.reverbAmount = reverbAmount
        self.reverbSize = reverbSize
        self.reverbDamping = reverbDamping
        self.inputGain = inputGain
        self.outputGain = outputGain
        self.volumeBoost = volumeBoost
        self.auxSignalBoostEnabled = auxSignalBoostEnabled
        self.auxSignalBoostDB = auxSignalBoostDB
        self.fmExciterEnabled = fmExciterEnabled
        self.fmExciterIntensity = fmExciterIntensity
        self.groundLoopSuppressorEnabled = groundLoopSuppressorEnabled
        self.groundLoopHumFrequency = groundLoopHumFrequency
        self.engineNoiseNotchEnabled = engineNoiseNotchEnabled
        self.engineNoiseFrequency = engineNoiseFrequency
        self.stereoCollapseEnabled = stereoCollapseEnabled
        self.stereoCollapseWidth = stereoCollapseWidth
        self.clipperProtectionEnabled = clipperProtectionEnabled
        self.logic7SpatializerEnabled = logic7SpatializerEnabled
        self.logic7Ambience = logic7Ambience
        self.logic7CenterFocus = logic7CenterFocus
        self.multibandCompressorEnabled = multibandCompressorEnabled
        self.adaptiveBassBoostEnabled = adaptiveBassBoostEnabled
        self.crossoverEnabled = crossoverEnabled
        self.crossoverFrequency = crossoverFrequency
        self.crossoverMode = crossoverMode
        self.subwooferPhaseInverted = subwooferPhaseInverted
        self.smartLoudBassMode = smartLoudBassMode
        self.subBassGain = subBassGain
        self.punchBassGain = punchBassGain
        self.warmthGain = warmthGain
        self.bassTightness = bassTightness
        self.subwooferModeEnabled = subwooferModeEnabled
        self.bassMonoBelow100Enabled = bassMonoBelow100Enabled
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bassBoostEnabled = try container.decodeIfPresent(Bool.self, forKey: .bassBoostEnabled) ?? false
        bassBoostIntensity = try container.decodeIfPresent(Float.self, forKey: .bassBoostIntensity) ?? 8
        bassBoostFrequency = try container.decodeIfPresent(Float.self, forKey: .bassBoostFrequency) ?? 80
        virtualSubwooferEnabled = try container.decodeIfPresent(Bool.self, forKey: .virtualSubwooferEnabled) ?? false
        virtualSubwooferMix = try container.decodeIfPresent(Float.self, forKey: .virtualSubwooferMix) ?? 0
        virtualSubwooferCutoff = try container.decodeIfPresent(Float.self, forKey: .virtualSubwooferCutoff) ?? 55
        cabinNotchEnabled = try container.decodeIfPresent(Bool.self, forKey: .cabinNotchEnabled) ?? false
        cabinNotchFrequency = try container.decodeIfPresent(Float.self, forKey: .cabinNotchFrequency) ?? 135
        cabinNotchQ = try container.decodeIfPresent(Float.self, forKey: .cabinNotchQ) ?? 6
        cabinNotchGain = try container.decodeIfPresent(Float.self, forKey: .cabinNotchGain) ?? -6
        trebleBoostEnabled = try container.decodeIfPresent(Bool.self, forKey: .trebleBoostEnabled) ?? false
        loudnessEnabled = try container.decodeIfPresent(Bool.self, forKey: .loudnessEnabled) ?? false
        compressorEnabled = try container.decodeIfPresent(Bool.self, forKey: .compressorEnabled) ?? false
        compressorThreshold = try container.decodeIfPresent(Float.self, forKey: .compressorThreshold) ?? -18
        compressorRatio = try container.decodeIfPresent(Float.self, forKey: .compressorRatio) ?? 3
        compressorAttack = try container.decodeIfPresent(Float.self, forKey: .compressorAttack) ?? 0.012
        compressorRelease = try container.decodeIfPresent(Float.self, forKey: .compressorRelease) ?? 0.18
        limiterEnabled = try container.decodeIfPresent(Bool.self, forKey: .limiterEnabled) ?? true
        limiterCeiling = try container.decodeIfPresent(Float.self, forKey: .limiterCeiling) ?? -1
        limiterRelease = try container.decodeIfPresent(Float.self, forKey: .limiterRelease) ?? 0.08
        stereoWideningEnabled = try container.decodeIfPresent(Bool.self, forKey: .stereoWideningEnabled) ?? false
        stereoWideningIntensity = try container.decodeIfPresent(Float.self, forKey: .stereoWideningIntensity) ?? 0.75
        spatialAudioEnabled = try container.decodeIfPresent(Bool.self, forKey: .spatialAudioEnabled) ?? false
        spatialAudioDepth = try container.decodeIfPresent(Float.self, forKey: .spatialAudioDepth) ?? 0.65
        surroundEnabled = try container.decodeIfPresent(Bool.self, forKey: .surroundEnabled) ?? false
        surroundAmount = try container.decodeIfPresent(Float.self, forKey: .surroundAmount) ?? 0.55
        eightDAudioEnabled = try container.decodeIfPresent(Bool.self, forKey: .eightDAudioEnabled) ?? false
        eightDAudioIntensity = try container.decodeIfPresent(Float.self, forKey: .eightDAudioIntensity) ?? 0.75
        eightDAudioSpeed = try container.decodeIfPresent(Float.self, forKey: .eightDAudioSpeed) ?? 0.30
        eightDAudioMode = try container.decodeIfPresent(EightDAudioMode.self, forKey: .eightDAudioMode) ?? .beatReactive
        softClipperEnabled = try container.decodeIfPresent(Bool.self, forKey: .softClipperEnabled) ?? false
        reverbAmount = try container.decodeIfPresent(Float.self, forKey: .reverbAmount) ?? 0
        reverbSize = try container.decodeIfPresent(Float.self, forKey: .reverbSize) ?? 0.45
        reverbDamping = try container.decodeIfPresent(Float.self, forKey: .reverbDamping) ?? 0.35
        inputGain = try container.decodeIfPresent(Float.self, forKey: .inputGain) ?? 0.82
        outputGain = try container.decodeIfPresent(Float.self, forKey: .outputGain) ?? 0.90
        volumeBoost = try container.decodeIfPresent(Float.self, forKey: .volumeBoost) ?? 1
        auxSignalBoostEnabled = try container.decodeIfPresent(Bool.self, forKey: .auxSignalBoostEnabled) ?? false
        auxSignalBoostDB = try container.decodeIfPresent(Float.self, forKey: .auxSignalBoostDB) ?? 0
        fmExciterEnabled = try container.decodeIfPresent(Bool.self, forKey: .fmExciterEnabled) ?? false
        fmExciterIntensity = try container.decodeIfPresent(Float.self, forKey: .fmExciterIntensity) ?? 0.35
        groundLoopSuppressorEnabled = try container.decodeIfPresent(Bool.self, forKey: .groundLoopSuppressorEnabled) ?? false
        groundLoopHumFrequency = try container.decodeIfPresent(Float.self, forKey: .groundLoopHumFrequency) ?? 50
        engineNoiseNotchEnabled = try container.decodeIfPresent(Bool.self, forKey: .engineNoiseNotchEnabled) ?? false
        engineNoiseFrequency = try container.decodeIfPresent(Float.self, forKey: .engineNoiseFrequency) ?? 120
        stereoCollapseEnabled = try container.decodeIfPresent(Bool.self, forKey: .stereoCollapseEnabled) ?? false
        stereoCollapseWidth = try container.decodeIfPresent(Float.self, forKey: .stereoCollapseWidth) ?? 1
        clipperProtectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .clipperProtectionEnabled) ?? true
        logic7SpatializerEnabled = try container.decodeIfPresent(Bool.self, forKey: .logic7SpatializerEnabled) ?? false
        logic7Ambience = try container.decodeIfPresent(Float.self, forKey: .logic7Ambience) ?? 0.35
        logic7CenterFocus = try container.decodeIfPresent(Float.self, forKey: .logic7CenterFocus) ?? 0.45
        multibandCompressorEnabled = try container.decodeIfPresent(Bool.self, forKey: .multibandCompressorEnabled) ?? false
        adaptiveBassBoostEnabled = try container.decodeIfPresent(Bool.self, forKey: .adaptiveBassBoostEnabled) ?? false
        subwooferPhaseInverted = try container.decodeIfPresent(Bool.self, forKey: .subwooferPhaseInverted) ?? false
        crossoverEnabled = try container.decodeIfPresent(Bool.self, forKey: .crossoverEnabled) ?? false
        crossoverFrequency = try container.decodeIfPresent(Float.self, forKey: .crossoverFrequency) ?? 80
        crossoverMode = try container.decodeIfPresent(CrossoverMode.self, forKey: .crossoverMode) ?? .subwoofer
        smartLoudBassMode = try container.decodeIfPresent(SmartLoudBassMode.self, forKey: .smartLoudBassMode) ?? .clean
        subBassGain = try container.decodeIfPresent(Float.self, forKey: .subBassGain) ?? 0
        punchBassGain = try container.decodeIfPresent(Float.self, forKey: .punchBassGain) ?? 0
        warmthGain = try container.decodeIfPresent(Float.self, forKey: .warmthGain) ?? 0
        bassTightness = try container.decodeIfPresent(Float.self, forKey: .bassTightness) ?? 0.5
        subwooferModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .subwooferModeEnabled) ?? false
        bassMonoBelow100Enabled = try container.decodeIfPresent(Bool.self, forKey: .bassMonoBelow100Enabled) ?? false
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bassBoostEnabled, forKey: .bassBoostEnabled)
        try container.encode(trebleBoostEnabled, forKey: .trebleBoostEnabled)
        try container.encode(loudnessEnabled, forKey: .loudnessEnabled)
        try container.encode(compressorEnabled, forKey: .compressorEnabled)
        try container.encode(compressorThreshold, forKey: .compressorThreshold)
        try container.encode(compressorRatio, forKey: .compressorRatio)
        try container.encode(compressorAttack, forKey: .compressorAttack)
        try container.encode(compressorRelease, forKey: .compressorRelease)
        try container.encode(limiterEnabled, forKey: .limiterEnabled)
        try container.encode(limiterCeiling, forKey: .limiterCeiling)
        try container.encode(limiterRelease, forKey: .limiterRelease)
        try container.encode(stereoWideningEnabled, forKey: .stereoWideningEnabled)
        try container.encode(stereoWideningIntensity, forKey: .stereoWideningIntensity)
        try container.encode(spatialAudioEnabled, forKey: .spatialAudioEnabled)
        try container.encode(spatialAudioDepth, forKey: .spatialAudioDepth)
        try container.encode(surroundEnabled, forKey: .surroundEnabled)
        try container.encode(surroundAmount, forKey: .surroundAmount)
        try container.encode(eightDAudioEnabled, forKey: .eightDAudioEnabled)
        try container.encode(eightDAudioIntensity, forKey: .eightDAudioIntensity)
        try container.encode(eightDAudioSpeed, forKey: .eightDAudioSpeed)
        try container.encode(eightDAudioMode, forKey: .eightDAudioMode)
        try container.encode(softClipperEnabled, forKey: .softClipperEnabled)
        try container.encode(reverbAmount, forKey: .reverbAmount)
        try container.encode(reverbSize, forKey: .reverbSize)
        try container.encode(reverbDamping, forKey: .reverbDamping)
        try container.encode(inputGain, forKey: .inputGain)
        try container.encode(outputGain, forKey: .outputGain)
        try container.encode(volumeBoost, forKey: .volumeBoost)
        try container.encode(auxSignalBoostEnabled, forKey: .auxSignalBoostEnabled)
        try container.encode(auxSignalBoostDB, forKey: .auxSignalBoostDB)
        try container.encode(fmExciterEnabled, forKey: .fmExciterEnabled)
        try container.encode(fmExciterIntensity, forKey: .fmExciterIntensity)
        try container.encode(groundLoopSuppressorEnabled, forKey: .groundLoopSuppressorEnabled)
        try container.encode(groundLoopHumFrequency, forKey: .groundLoopHumFrequency)
        try container.encode(engineNoiseNotchEnabled, forKey: .engineNoiseNotchEnabled)
        try container.encode(engineNoiseFrequency, forKey: .engineNoiseFrequency)
        try container.encode(stereoCollapseEnabled, forKey: .stereoCollapseEnabled)
        try container.encode(stereoCollapseWidth, forKey: .stereoCollapseWidth)
        try container.encode(clipperProtectionEnabled, forKey: .clipperProtectionEnabled)
        try container.encode(logic7SpatializerEnabled, forKey: .logic7SpatializerEnabled)
        try container.encode(logic7Ambience, forKey: .logic7Ambience)
        try container.encode(logic7CenterFocus, forKey: .logic7CenterFocus)
        try container.encode(multibandCompressorEnabled, forKey: .multibandCompressorEnabled)
        try container.encode(bassBoostIntensity, forKey: .bassBoostIntensity)
        try container.encode(bassBoostFrequency, forKey: .bassBoostFrequency)
        try container.encode(virtualSubwooferEnabled, forKey: .virtualSubwooferEnabled)
        try container.encode(virtualSubwooferMix, forKey: .virtualSubwooferMix)
        try container.encode(virtualSubwooferCutoff, forKey: .virtualSubwooferCutoff)
        try container.encode(cabinNotchEnabled, forKey: .cabinNotchEnabled)
        try container.encode(cabinNotchFrequency, forKey: .cabinNotchFrequency)
        try container.encode(cabinNotchQ, forKey: .cabinNotchQ)
        try container.encode(cabinNotchGain, forKey: .cabinNotchGain)
        try container.encode(adaptiveBassBoostEnabled, forKey: .adaptiveBassBoostEnabled)
        try container.encode(crossoverEnabled, forKey: .crossoverEnabled)
        try container.encode(crossoverFrequency, forKey: .crossoverFrequency)
        try container.encode(crossoverMode, forKey: .crossoverMode)
        try container.encode(subwooferPhaseInverted, forKey: .subwooferPhaseInverted)
        try container.encode(smartLoudBassMode, forKey: .smartLoudBassMode)
        try container.encode(subBassGain, forKey: .subBassGain)
        try container.encode(punchBassGain, forKey: .punchBassGain)
        try container.encode(warmthGain, forKey: .warmthGain)
        try container.encode(bassTightness, forKey: .bassTightness)
        try container.encode(subwooferModeEnabled, forKey: .subwooferModeEnabled)
        try container.encode(bassMonoBelow100Enabled, forKey: .bassMonoBelow100Enabled)
    }
}
