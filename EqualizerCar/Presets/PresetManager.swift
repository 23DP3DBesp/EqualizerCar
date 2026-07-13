import Foundation
import Combine
import SwiftData

@MainActor
class PresetManager: ObservableObject {
    @Published var presets: [Preset] = []
    @Published var activePresetID: UUID?

    private var modelContext: ModelContext?
    private var userPresetsFileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("user_presets.json")
    }

    init() {
        presets = Self.builtInPresets
        loadUserPresets()
    }

    func configureModelContext(_ context: ModelContext) {
        modelContext = context
        loadSwiftDataUserPresets()
        migrateJSONPresetsToSwiftData()
    }

    static let builtInPresets: [Preset] = [
        makePreset("Studio (Flat)", [0, 0, 0, 0, 0]),
        makePreset("Car Audio Premium", [4, 1, 2, 3, 2], effects: PresetEffectSettings(
            bassBoostEnabled: true, trebleBoostEnabled: true, loudnessEnabled: true,
            compressorEnabled: true, limiterEnabled: true, stereoWideningEnabled: true,
            reverbAmount: 8, volumeBoost: 1.25
        )),
        makePreset("8D Drive", [3, 1, 0, 2, 3], effects: PresetEffectSettings(
            limiterEnabled: true, stereoWideningEnabled: true, stereoWideningIntensity: 0.85,
            spatialAudioEnabled: true, spatialAudioDepth: 0.75, surroundEnabled: true,
            surroundAmount: 0.32, eightDAudioEnabled: true, eightDAudioIntensity: 0.85,
            eightDAudioSpeed: 0.35, reverbAmount: 5, volumeBoost: 1.10
        )),
        makePreset("Bass Monster", [10, 5, 0, -1, -2], effects: PresetEffectSettings(
            bassBoostEnabled: true, loudnessEnabled: true, compressorEnabled: true,
            limiterEnabled: true, volumeBoost: 1.75
        )),
        makePreset("Speaker Destroyer", [12, 8, 4, 6, 8], effects: PresetEffectSettings(
            bassBoostEnabled: true, trebleBoostEnabled: true, loudnessEnabled: true,
            compressorEnabled: true, limiterEnabled: false, stereoWideningEnabled: true,
            reverbAmount: 4, volumeBoost: 2.5
        )),
        makePreset("Deep Clean Bass", [7, 3, -1, 1, 0], effects: PresetEffectSettings(
            bassBoostEnabled: true, compressorEnabled: true, limiterEnabled: true, volumeBoost: 1.25
        )),
        makePreset("Subwoofer Focus", [9, 4, -2, -2, -3], effects: PresetEffectSettings(
            bassBoostEnabled: true, compressorEnabled: true, limiterEnabled: true, inputGain: 0.76
        )),
        makePreset("Vocal Clarity", [-2, -1, 3, 5, 3], effects: PresetEffectSettings(
            trebleBoostEnabled: true, limiterEnabled: true
        )),
        makePreset("Podcast Voice", [-4, -2, 4, 3, -1], effects: PresetEffectSettings(
            compressorEnabled: true, compressorThreshold: -24, compressorRatio: 4, limiterEnabled: true
        )),
        makePreset("Acoustic Warmth", [2, 3, 1, 2, 1], effects: PresetEffectSettings(
            limiterEnabled: true, reverbAmount: 6, reverbSize: 0.35
        )),
        makePreset("Rock Arena", [5, 2, -1, 4, 3], effects: PresetEffectSettings(
            compressorEnabled: true, limiterEnabled: true, stereoWideningEnabled: true,
            stereoWideningIntensity: 0.65, reverbAmount: 10
        )),
        makePreset("Metal Attack", [4, 1, -2, 6, 5], effects: PresetEffectSettings(
            trebleBoostEnabled: true, compressorEnabled: true, compressorRatio: 5, limiterEnabled: true
        )),
        makePreset("Hip-Hop Club", [8, 4, -1, 2, 2], effects: PresetEffectSettings(
            bassBoostEnabled: true, loudnessEnabled: true, compressorEnabled: true,
            limiterEnabled: true, volumeBoost: 1.35
        )),
        makePreset("EDM Festival", [6, 2, 0, 4, 5], effects: PresetEffectSettings(
            bassBoostEnabled: true, trebleBoostEnabled: true, loudnessEnabled: true,
            compressorEnabled: true, limiterEnabled: true, stereoWideningEnabled: true,
            stereoWideningIntensity: 0.9, volumeBoost: 1.3
        )),
        makePreset("Pop Shine", [3, 1, 1, 4, 4], effects: PresetEffectSettings(
            trebleBoostEnabled: true, loudnessEnabled: true, limiterEnabled: true, volumeBoost: 1.15
        )),
        makePreset("Jazz Lounge", [2, 2, 1, 2, 2], effects: PresetEffectSettings(
            limiterEnabled: true, stereoWideningEnabled: true, stereoWideningIntensity: 0.45,
            reverbAmount: 7, reverbSize: 0.42
        )),
        makePreset("Classical Hall", [1, 1, 0, 2, 3], effects: PresetEffectSettings(
            limiterEnabled: true, surroundEnabled: true, surroundAmount: 0.28,
            reverbAmount: 12, reverbSize: 0.68, outputGain: 0.86
        )),
        makePreset("Lo-Fi Tape", [4, 2, -1, -3, -5], effects: PresetEffectSettings(
            compressorEnabled: true, compressorThreshold: -28, compressorRatio: 2.5,
            limiterEnabled: true, reverbAmount: 4, outputGain: 0.84
        )),
        makePreset("Night Drive", [5, 2, -1, 1, 2], effects: PresetEffectSettings(
            bassBoostEnabled: true, limiterEnabled: true, stereoWideningEnabled: true,
            stereoWideningIntensity: 0.72, spatialAudioEnabled: true, spatialAudioDepth: 0.45
        )),
        makePreset("Small Speakers", [3, 2, 2, 3, 1], effects: PresetEffectSettings(
            loudnessEnabled: true, compressorEnabled: true, limiterEnabled: true, volumeBoost: 1.2
        )),
        makePreset("Headphones Wide", [2, 0, 0, 3, 3], effects: PresetEffectSettings(
            limiterEnabled: true, stereoWideningEnabled: true, stereoWideningIntensity: 1,
            spatialAudioEnabled: true, spatialAudioDepth: 0.7
        )),
        makePreset("AirPods Clean", [2, -1, 1, 3, 2], effects: PresetEffectSettings(
            compressorEnabled: true, compressorThreshold: -20, limiterEnabled: true,
            stereoWideningEnabled: true, stereoWideningIntensity: 0.5
        )),
        makePreset("Old Radio", [-5, 1, 4, -2, -8], effects: PresetEffectSettings(
            compressorEnabled: true, compressorRatio: 6, limiterEnabled: true, outputGain: 0.78
        )),
        makePreset("Cinema Surround", [4, 1, -1, 3, 4], effects: PresetEffectSettings(
            limiterEnabled: true, spatialAudioEnabled: true, spatialAudioDepth: 0.85,
            surroundEnabled: true, surroundAmount: 0.55, reverbAmount: 9
        )),
        makePreset("Gaming Footsteps", [-3, -2, 3, 6, 4], effects: PresetEffectSettings(
            limiterEnabled: true, stereoWideningEnabled: true, stereoWideningIntensity: 0.8,
            spatialAudioEnabled: true, spatialAudioDepth: 0.55
        )),
        makePreset("Maximum Loudness", [5, 3, 2, 3, 4], effects: PresetEffectSettings(
            loudnessEnabled: true, compressorEnabled: true, compressorThreshold: -30,
            compressorRatio: 6, limiterEnabled: true, limiterCeiling: -1.5,
            inputGain: 0.72, outputGain: 0.88, volumeBoost: 1.8
        ))
    ]

    private static func makePreset(
        _ name: String,
        _ gains: [Float],
        effects: PresetEffectSettings = PresetEffectSettings(limiterEnabled: true)
    ) -> Preset {
        let frequencies: [Float] = [60, 250, 1000, 4000, 12000]
        let points = zip(frequencies, gains).map { PresetPoint(frequency: $0, gain: $1) }
        return Preset(name: name, points: points, effects: effects, isBuiltIn: true, category: inferredCategory(for: name))
    }

    private static func inferredCategory(for name: String) -> PresetCategory {
        let lowercasedName = name.lowercased()
        if lowercasedName.contains("bass") || lowercasedName.contains("subwoofer") || lowercasedName.contains("hip-hop") {
            return .bass
        }
        if lowercasedName.contains("vocal") || lowercasedName.contains("voice") || lowercasedName.contains("podcast") {
            return .vocal
        }
        if lowercasedName.contains("car") || lowercasedName.contains("drive") {
            return .car
        }
        if lowercasedName.contains("headphones") || lowercasedName.contains("airpods") {
            return .headphones
        }
        if lowercasedName.contains("8d") {
            return .eightD
        }
        if lowercasedName.contains("cinema") || lowercasedName.contains("gaming") {
            return .cinema
        }
        if lowercasedName.contains("loud") || lowercasedName.contains("destroyer") {
            return .loud
        }
        return .custom
    }

    func apply(_ preset: Preset, to audioManager: AudioEngineManager) {
        let gains = audioManager.bandFrequencies.map { frequency in
            preset.points.min { first, second in
                abs(log10(first.frequency) - log10(frequency)) < abs(log10(second.frequency) - log10(frequency))
            }?.gain ?? 0
        }
        audioManager.applyGains(gains)
        audioManager.applyEffects(preset.effects)
        activePresetID = preset.id
        saveProfileHistory(name: preset.name, effects: preset.effects)
    }

    func saveCurrentAsPreset(name: String, audioManager: AudioEngineManager) {
        let points = zip(audioManager.bandFrequencies, audioManager.bandGains).map {
            PresetPoint(frequency: $0, gain: $1)
        }
        let newPreset = Preset(
            name: name,
            points: points,
            effects: audioManager.currentEffectSettings(),
            isBuiltIn: false
        )
        presets.append(newPreset)
        savePresetToSwiftData(newPreset)
        saveProfileHistory(name: name, effects: newPreset.effects)
        saveUserPresets()
    }

    func deletePreset(_ preset: Preset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
        if activePresetID == preset.id {
            activePresetID = nil
        }
        deletePresetFromSwiftData(preset)
        saveUserPresets()
    }

    func duplicatePreset(_ preset: Preset) {
        let copy = Preset(
            name: "\(preset.name) Copy",
            points: preset.points,
            effects: preset.effects,
            isBuiltIn: false,
            category: preset.category
        )
        presets.append(copy)
        savePresetToSwiftData(copy)
        saveUserPresets()
    }

    func toggleFavorite(_ preset: Preset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].isFavorite.toggle()
        savePresetToSwiftData(presets[index])
        saveUserPresets()
    }

    func presets(in category: PresetCategory, favoritesOnly: Bool) -> [Preset] {
        presets.filter { preset in
            let categoryMatches = category == .all || preset.category == category
            let favoriteMatches = !favoritesOnly || preset.isFavorite
            return categoryMatches && favoriteMatches
        }
    }

    func userPresets() -> [Preset] {
        presets.filter { !$0.isBuiltIn }
    }

    func exportUserPresetsData() -> Data {
        do {
            return try JSONEncoder().encode(userPresets())
        } catch {
            print("Ошибка экспорта пресетов: \(error)")
            return Data()
        }
    }

    func importUserPresets(from data: Data) {
        do {
            let importedPresets = try JSONDecoder().decode([Preset].self, from: data)
            let existingIDs = Set(presets.map(\.id))
            let newPresets = importedPresets
                .filter { !existingIDs.contains($0.id) }
                .map { preset in
                    Preset(
                        id: preset.id,
                        name: preset.name,
                        points: preset.points,
                        effects: preset.effects,
                        isBuiltIn: false,
                        category: preset.category,
                        isFavorite: preset.isFavorite
                    )
                }
            guard !newPresets.isEmpty else { return }
            presets.append(contentsOf: newPresets)
            newPresets.forEach(savePresetToSwiftData)
            saveUserPresets()
        } catch {
            print("Ошибка импорта пресетов: \(error)")
        }
    }

    private func saveUserPresets() {
        do {
            let data = try JSONEncoder().encode(userPresets())
            try data.write(to: userPresetsFileURL)
        } catch {
            print("Ошибка сохранения пресетов: \(error)")
        }
    }

    private func loadUserPresets() {
        guard FileManager.default.fileExists(atPath: userPresetsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: userPresetsFileURL)
            let userPresets = try JSONDecoder().decode([Preset].self, from: data)
            presets.append(contentsOf: userPresets)
        } catch {
            print("Ошибка загрузки пресетов: \(error)")
        }
    }

    private func loadSwiftDataUserPresets() {
        guard let modelContext else { return }
        do {
            let descriptor = FetchDescriptor<StoredPreset>(predicate: #Predicate { !$0.isBuiltIn })
            let storedPresets = try modelContext.fetch(descriptor).map(\.preset)
            let builtIns = Self.builtInPresets
            let builtInIDs = Set(builtIns.map(\.id))
            presets = builtIns + storedPresets.filter { !builtInIDs.contains($0.id) }
        } catch {
            print("Ошибка загрузки SwiftData пресетов: \(error)")
        }
    }

    private func savePresetToSwiftData(_ preset: Preset) {
        guard let modelContext, !preset.isBuiltIn else { return }
        do {
            let id = preset.id
            let descriptor = FetchDescriptor<StoredPreset>(predicate: #Predicate { $0.id == id })
            for existingPreset in try modelContext.fetch(descriptor) {
                modelContext.delete(existingPreset)
            }
            modelContext.insert(StoredPreset(preset: preset))
            try modelContext.save()
        } catch {
            print("Ошибка сохранения SwiftData пресета: \(error)")
        }
    }

    private func deletePresetFromSwiftData(_ preset: Preset) {
        guard let modelContext else { return }
        do {
            let id = preset.id
            let descriptor = FetchDescriptor<StoredPreset>(predicate: #Predicate { $0.id == id })
            for storedPreset in try modelContext.fetch(descriptor) {
                modelContext.delete(storedPreset)
            }
            try modelContext.save()
        } catch {
            print("Ошибка удаления SwiftData пресета: \(error)")
        }
    }

    private func migrateJSONPresetsToSwiftData() {
        guard modelContext != nil else { return }
        userPresets().forEach(savePresetToSwiftData)
    }

    private func saveProfileHistory(name: String, effects: PresetEffectSettings) {
        guard let modelContext else { return }
        modelContext.insert(ProfileHistoryEntry(presetName: name, effects: effects))
        do {
            try modelContext.save()
        } catch {
            print("Ошибка сохранения истории профиля: \(error)")
        }
    }
}
