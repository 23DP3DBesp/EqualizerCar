import Foundation
import Combine
import SwiftData

@MainActor
class PresetManager: ObservableObject {
    @Published var presets: [Preset] = []
    @Published var activePresetID: UUID?
    @Published var quickPresetNames: [String] {
        didSet {
            UserDefaults.standard.set(quickPresetNames, forKey: Self.quickPresetNamesKey)
        }
    }

    private var modelContext: ModelContext?
    private var lastProfileHistorySave = Date.distantPast
    private static let quickPresetNamesKey = "quickPresetNames"
    private static let defaultQuickPresetNames = [
        "W211 OEM Audio 20 (AUX-Fix + Anti-Boom)",
        "W211 Harman Kardon Logic 7 (Full Clarity)",
        "Legacy FM Transmitter (Highs Recovery & Mono Punch)",
        "Deep Bass & Sub-Harmonics (Small Speakers)",
        "Highway Noise Comp (Vocal & Clarity)"
    ]
    private static let retiredBuiltInPresetNames: Set<String> = [
        "Flat",
        "Pop",
        "Acoustic",
        "Rock",
        "Classical",
        "Dance",
        "Electronic",
        "Hip-Hop",
        "Jazz",
        "Podcast"
    ]

    private var userPresetsFileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("user_presets.json")
    }

    init() {
        quickPresetNames = UserDefaults.standard.stringArray(forKey: Self.quickPresetNamesKey) ?? Self.defaultQuickPresetNames
        presets = Self.builtInPresets
        loadUserPresets()
        sanitizeQuickPresets()
    }

    func configureModelContext(_ context: ModelContext) {
        modelContext = context
        loadSwiftDataUserPresets()
        migrateJSONPresetsToSwiftData()
    }

    static let builtInPresets: [Preset] = [
        makePreset("W211 OEM Audio 20 (AUX-Fix + Anti-Boom)", [5, 1, -1, 2, 3], effects: PresetEffectSettings(
            bassBoostEnabled: true,
            bassBoostIntensity: 5.5,
            bassBoostFrequency: 58,
            virtualSubwooferEnabled: true,
            virtualSubwooferMix: 0.35,
            virtualSubwooferCutoff: 55,
            cabinNotchEnabled: true,
            cabinNotchFrequency: 135,
            cabinNotchQ: 6.5,
            cabinNotchGain: -6,
            compressorEnabled: true,
            compressorThreshold: -22,
            compressorRatio: 3.2,
            limiterEnabled: true,
            limiterCeiling: -1.5,
            inputGain: 0.76,
            outputGain: 0.86,
            volumeBoost: 1.12,
            auxSignalBoostEnabled: true,
            auxSignalBoostDB: 6,
            stereoCollapseEnabled: true,
            stereoCollapseWidth: 0.78,
            clipperProtectionEnabled: true
        ), category: .car),
        makePreset("W211 Harman Kardon Logic 7 (Full Clarity)", [2, 0, -1, 2.5, 3.5], effects: PresetEffectSettings(
            bassBoostEnabled: true,
            bassBoostIntensity: 3.5,
            bassBoostFrequency: 70,
            cabinNotchEnabled: true,
            cabinNotchFrequency: 130,
            cabinNotchQ: 5.5,
            cabinNotchGain: -3.5,
            compressorEnabled: true,
            compressorThreshold: -20,
            compressorRatio: 2.4,
            limiterEnabled: true,
            limiterCeiling: -1.2,
            stereoWideningEnabled: true,
            stereoWideningIntensity: 0.85,
            spatialAudioEnabled: true,
            spatialAudioDepth: 0.28,
            inputGain: 0.78,
            outputGain: 0.86,
            auxSignalBoostEnabled: true,
            auxSignalBoostDB: 3,
            clipperProtectionEnabled: true,
            logic7SpatializerEnabled: true,
            logic7Ambience: 0.42,
            logic7CenterFocus: 0.62
        ), category: .car),
        makePreset("Legacy FM Transmitter (Highs Recovery & Mono Punch)", [3, -1, 1, 4.5, 5.5], effects: PresetEffectSettings(
            bassBoostEnabled: true,
            trebleBoostEnabled: true,
            loudnessEnabled: true,
            bassBoostIntensity: 4,
            bassBoostFrequency: 78,
            compressorEnabled: true,
            compressorThreshold: -24,
            compressorRatio: 4.0,
            limiterEnabled: true,
            limiterCeiling: -2,
            inputGain: 0.74,
            outputGain: 0.82,
            volumeBoost: 1.08,
            fmExciterEnabled: true,
            fmExciterIntensity: 0.55,
            stereoCollapseEnabled: true,
            stereoCollapseWidth: 0.60,
            clipperProtectionEnabled: true
        ), category: .car),
        makePreset("Deep Bass & Sub-Harmonics (Small Speakers)", [7, 3, -2, 0, 1], effects: PresetEffectSettings(
            bassBoostEnabled: true,
            bassBoostIntensity: 7.5,
            bassBoostFrequency: 52,
            virtualSubwooferEnabled: true,
            virtualSubwooferMix: 0.65,
            virtualSubwooferCutoff: 62,
            cabinNotchEnabled: true,
            cabinNotchFrequency: 145,
            cabinNotchQ: 7,
            cabinNotchGain: -5,
            compressorEnabled: true,
            compressorThreshold: -25,
            compressorRatio: 4.4,
            limiterEnabled: true,
            limiterCeiling: -2.5,
            inputGain: 0.72,
            outputGain: 0.84,
            clipperProtectionEnabled: true,
            crossoverEnabled: true,
            crossoverFrequency: 25,
            crossoverMode: .speakers,
            subBassGain: 5.5,
            punchBassGain: 3,
            warmthGain: -1,
            bassTightness: 0.82
        ), category: .bass),
        makePreset("Highway Noise Comp (Vocal & Clarity)", [1, -1, 3.5, 4, 3], effects: PresetEffectSettings(
            bassBoostEnabled: true,
            trebleBoostEnabled: true,
            loudnessEnabled: true,
            bassBoostIntensity: 2.5,
            bassBoostFrequency: 85,
            cabinNotchEnabled: true,
            cabinNotchFrequency: 138,
            cabinNotchQ: 6,
            cabinNotchGain: -5.5,
            compressorEnabled: true,
            compressorThreshold: -27,
            compressorRatio: 4.8,
            compressorAttack: 0.008,
            compressorRelease: 0.16,
            limiterEnabled: true,
            limiterCeiling: -1.5,
            stereoWideningEnabled: true,
            stereoWideningIntensity: 0.42,
            inputGain: 0.76,
            outputGain: 0.88,
            volumeBoost: 1.16,
            clipperProtectionEnabled: true
        ), category: .car)
    ]

    private static func makePreset(
        _ name: String,
        _ gains: [Float],
        effects: PresetEffectSettings = PresetEffectSettings(limiterEnabled: true),
        category: PresetCategory? = nil
    ) -> Preset {
        let frequencies: [Float] = [60, 250, 1000, 4000, 12000]
        let points = zip(frequencies, gains).map { PresetPoint(frequency: $0, gain: $1) }
        return Preset(name: name, points: points, effects: effects, isBuiltIn: true, category: category ?? inferredCategory(for: name))
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
        let filterTypes = audioManager.bandFrequencies.map { frequency in
            preset.points.min { first, second in
                abs(log10(first.frequency) - log10(frequency)) < abs(log10(second.frequency) - log10(frequency))
            }?.filterType ?? .parametric
        }
        audioManager.applyGains(gains)
        audioManager.applyFilterTypes(filterTypes)
        audioManager.applyEffects(preset.effects)
        activePresetID = preset.id
        saveProfileHistoryIfNeeded(name: preset.name, effects: preset.effects)
    }

    func saveCurrentAsPreset(name: String, audioManager: AudioEngineManager) {
        let points = zip(zip(audioManager.bandFrequencies, audioManager.bandGains), audioManager.bandFilterTypes).map { frequencyAndGain, filterType in
            PresetPoint(frequency: frequencyAndGain.0, gain: frequencyAndGain.1, filterType: filterType)
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
        quickPresetNames.removeAll { $0 == preset.name }
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

    var quickPresets: [Preset] {
        quickPresetNames.compactMap { name in
            presets.first { $0.name == name }
        }
    }

    var availableQuickPresetCandidates: [Preset] {
        presets.filter { !quickPresetNames.contains($0.name) }
    }

    func addQuickPreset(_ preset: Preset) {
        guard !quickPresetNames.contains(preset.name) else { return }
        quickPresetNames.append(preset.name)
    }

    func removeQuickPreset(_ preset: Preset) {
        quickPresetNames.removeAll { $0 == preset.name }
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
                .filter { !existingIDs.contains($0.id) && !Self.isRetiredBuiltInPresetName($0.name) }
                .map { preset in
                    Self.normalizedUserPreset(Preset(
                        id: preset.id,
                        name: preset.name,
                        points: preset.points,
                        effects: preset.effects,
                        isBuiltIn: false,
                        category: preset.category,
                        isFavorite: preset.isFavorite
                    ))
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
                .filter { !Self.isRetiredBuiltInPresetName($0.name) }
                .map(Self.normalizedUserPreset)
            presets.append(contentsOf: userPresets)
            sanitizeQuickPresets()
        } catch {
            print("Ошибка загрузки пресетов: \(error)")
        }
    }

    private func sanitizeQuickPresets() {
        let availableNames = Set(presets.map(\.name))
        quickPresetNames = quickPresetNames.filter { availableNames.contains($0) }
        if quickPresetNames.isEmpty {
            quickPresetNames = Self.defaultQuickPresetNames.filter { availableNames.contains($0) }
        }
    }

    private func loadSwiftDataUserPresets() {
        guard let modelContext else { return }
        do {
            let descriptor = FetchDescriptor<StoredPreset>(predicate: #Predicate { !$0.isBuiltIn })
            let storedPresets = try modelContext.fetch(descriptor)
                .map(\.preset)
                .filter { !Self.isRetiredBuiltInPresetName($0.name) }
                .map(Self.normalizedUserPreset)
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

    private static func isRetiredBuiltInPresetName(_ name: String) -> Bool {
        retiredBuiltInPresetNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func normalizedUserPreset(_ preset: Preset) -> Preset {
        Preset(
            id: preset.id,
            name: preset.name,
            points: preset.points.map(normalizedPoint),
            effects: normalizedEffects(preset.effects),
            isBuiltIn: false,
            category: preset.category,
            isFavorite: preset.isFavorite
        )
    }

    private static func normalizedPoint(_ point: PresetPoint) -> PresetPoint {
        PresetPoint(
            frequency: clamp(point.frequency, 20, 20_000),
            gain: clamp(point.gain, -18, 18),
            filterType: point.filterType
        )
    }

    private static func normalizedEffects(_ effects: PresetEffectSettings) -> PresetEffectSettings {
        PresetEffectSettings(
            bassBoostEnabled: effects.bassBoostEnabled,
            trebleBoostEnabled: effects.trebleBoostEnabled,
            loudnessEnabled: effects.loudnessEnabled,
            bassBoostIntensity: clamp(effects.bassBoostIntensity, 0, 12),
            bassBoostFrequency: clamp(effects.bassBoostFrequency, 40, 150),
            virtualSubwooferEnabled: effects.virtualSubwooferEnabled,
            virtualSubwooferMix: clamp(effects.virtualSubwooferMix, 0, 1),
            virtualSubwooferCutoff: clamp(effects.virtualSubwooferCutoff, 30, 70),
            cabinNotchEnabled: effects.cabinNotchEnabled,
            cabinNotchFrequency: clamp(effects.cabinNotchFrequency, 100, 200),
            cabinNotchQ: clamp(effects.cabinNotchQ, 4, 8),
            cabinNotchGain: clamp(effects.cabinNotchGain, -18, 0),
            compressorEnabled: effects.compressorEnabled,
            compressorThreshold: clamp(effects.compressorThreshold, -60, 0),
            compressorRatio: clamp(effects.compressorRatio, 1, 20),
            compressorAttack: clamp(effects.compressorAttack, 0.001, 0.100),
            compressorRelease: clamp(effects.compressorRelease, 0.020, 1.000),
            limiterEnabled: effects.limiterEnabled,
            limiterCeiling: clamp(effects.limiterCeiling, -12, 0),
            limiterRelease: clamp(effects.limiterRelease, 0.010, 0.500),
            stereoWideningEnabled: effects.stereoWideningEnabled,
            stereoWideningIntensity: clamp(effects.stereoWideningIntensity, 0, 1),
            spatialAudioEnabled: effects.spatialAudioEnabled,
            spatialAudioDepth: clamp(effects.spatialAudioDepth, 0, 1),
            surroundEnabled: effects.surroundEnabled,
            surroundAmount: clamp(effects.surroundAmount, 0, 1),
            eightDAudioEnabled: effects.eightDAudioEnabled,
            eightDAudioIntensity: clamp(effects.eightDAudioIntensity, 0, 1),
            eightDAudioSpeed: clamp(effects.eightDAudioSpeed, 0.03, 0.75),
            eightDAudioMode: effects.eightDAudioMode,
            softClipperEnabled: effects.softClipperEnabled,
            reverbAmount: clamp(effects.reverbAmount, 0, 100),
            reverbSize: clamp(effects.reverbSize, 0, 1),
            reverbDamping: clamp(effects.reverbDamping, 0, 1),
            inputGain: clamp(effects.inputGain, 0, 1.25),
            outputGain: clamp(effects.outputGain, 0, 1.25),
            volumeBoost: clamp(effects.volumeBoost, 1, 3),
            auxSignalBoostEnabled: effects.auxSignalBoostEnabled,
            auxSignalBoostDB: clamp(effects.auxSignalBoostDB, 0, 12),
            fmExciterEnabled: effects.fmExciterEnabled,
            fmExciterIntensity: clamp(effects.fmExciterIntensity, 0, 1),
            groundLoopSuppressorEnabled: effects.groundLoopSuppressorEnabled,
            groundLoopHumFrequency: clamp(effects.groundLoopHumFrequency, 45, 65),
            engineNoiseNotchEnabled: effects.engineNoiseNotchEnabled,
            engineNoiseFrequency: clamp(effects.engineNoiseFrequency, 80, 420),
            stereoCollapseEnabled: effects.stereoCollapseEnabled,
            stereoCollapseWidth: clamp(effects.stereoCollapseWidth, 0, 1),
            clipperProtectionEnabled: effects.clipperProtectionEnabled,
            logic7SpatializerEnabled: effects.logic7SpatializerEnabled,
            logic7Ambience: clamp(effects.logic7Ambience, 0, 1),
            logic7CenterFocus: clamp(effects.logic7CenterFocus, 0, 1),
            multibandCompressorEnabled: effects.multibandCompressorEnabled,
            adaptiveBassBoostEnabled: effects.adaptiveBassBoostEnabled,
            crossoverEnabled: effects.crossoverEnabled,
            crossoverFrequency: clamp(effects.crossoverFrequency, 25, 200),
            crossoverMode: effects.crossoverMode,
            subwooferPhaseInverted: effects.subwooferPhaseInverted,
            smartLoudBassMode: effects.smartLoudBassMode,
            subBassGain: clamp(effects.subBassGain, -12, 12),
            punchBassGain: clamp(effects.punchBassGain, -12, 12),
            warmthGain: clamp(effects.warmthGain, -12, 12),
            bassTightness: clamp(effects.bassTightness, 0, 1),
            subwooferModeEnabled: effects.subwooferModeEnabled,
            bassMonoBelow100Enabled: effects.bassMonoBelow100Enabled
        )
    }

    private static func clamp(_ value: Float, _ lowerBound: Float, _ upperBound: Float) -> Float {
        guard value.isFinite else { return lowerBound }
        return min(max(value, lowerBound), upperBound)
    }

    private func saveProfileHistoryIfNeeded(name: String, effects: PresetEffectSettings) {
        let now = Date()
        guard now.timeIntervalSince(lastProfileHistorySave) > 4 else { return }
        lastProfileHistorySave = now
        saveProfileHistory(name: name, effects: effects)
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
