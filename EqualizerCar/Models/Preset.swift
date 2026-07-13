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
}

struct PresetPoint: Codable, Equatable, Sendable {
    let frequency: Float
    let gain: Float
}

struct PresetEffectSettings: Codable, Equatable, Sendable {
    var bassBoostEnabled: Bool = false
    var trebleBoostEnabled: Bool = false
    var loudnessEnabled: Bool = false
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
    var softClipperEnabled: Bool = false
    var reverbAmount: Float = 0
    var reverbSize: Float = 0.45
    var reverbDamping: Float = 0.35
    var inputGain: Float = 0.82
    var outputGain: Float = 0.90
    var volumeBoost: Float = 1

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
        case softClipperEnabled
        case reverbAmount
        case reverbSize
        case reverbDamping
        case inputGain
        case outputGain
        case volumeBoost
    }

    nonisolated init(
        bassBoostEnabled: Bool = false,
        trebleBoostEnabled: Bool = false,
        loudnessEnabled: Bool = false,
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
        softClipperEnabled: Bool = false,
        reverbAmount: Float = 0,
        reverbSize: Float = 0.45,
        reverbDamping: Float = 0.35,
        inputGain: Float = 0.82,
        outputGain: Float = 0.90,
        volumeBoost: Float = 1
    ) {
        self.bassBoostEnabled = bassBoostEnabled
        self.trebleBoostEnabled = trebleBoostEnabled
        self.loudnessEnabled = loudnessEnabled
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
        self.softClipperEnabled = softClipperEnabled
        self.reverbAmount = reverbAmount
        self.reverbSize = reverbSize
        self.reverbDamping = reverbDamping
        self.inputGain = inputGain
        self.outputGain = outputGain
        self.volumeBoost = volumeBoost
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bassBoostEnabled = try container.decodeIfPresent(Bool.self, forKey: .bassBoostEnabled) ?? false
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
        softClipperEnabled = try container.decodeIfPresent(Bool.self, forKey: .softClipperEnabled) ?? false
        reverbAmount = try container.decodeIfPresent(Float.self, forKey: .reverbAmount) ?? 0
        reverbSize = try container.decodeIfPresent(Float.self, forKey: .reverbSize) ?? 0.45
        reverbDamping = try container.decodeIfPresent(Float.self, forKey: .reverbDamping) ?? 0.35
        inputGain = try container.decodeIfPresent(Float.self, forKey: .inputGain) ?? 0.82
        outputGain = try container.decodeIfPresent(Float.self, forKey: .outputGain) ?? 0.90
        volumeBoost = try container.decodeIfPresent(Float.self, forKey: .volumeBoost) ?? 1
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
        try container.encode(softClipperEnabled, forKey: .softClipperEnabled)
        try container.encode(reverbAmount, forKey: .reverbAmount)
        try container.encode(reverbSize, forKey: .reverbSize)
        try container.encode(reverbDamping, forKey: .reverbDamping)
        try container.encode(inputGain, forKey: .inputGain)
        try container.encode(outputGain, forKey: .outputGain)
        try container.encode(volumeBoost, forKey: .volumeBoost)
    }
}
