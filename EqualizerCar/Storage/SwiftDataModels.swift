import Foundation
import SwiftData

@Model
final class StoredTrack {
    @Attribute(.unique) var id: UUID
    var artist: String?
    @Attribute(.externalStorage) var artworkData: Data?
    var title: String
    var fileName: String
    var dateAdded: Date
    var duration: Double
    var waveformData: Data
    var isFavorite: Bool = false
    var lastPlayedAt: Date?
    var presetSnapshotData: Data = Data()

    init(track: Track) {
        id = track.id
        title = track.title
        artist = track.artist
        artworkData = track.artworkData
        fileName = track.fileName
        dateAdded = track.dateAdded
        duration = track.duration
        waveformData = Data()
        isFavorite = track.isFavorite
        lastPlayedAt = track.lastPlayedAt
        presetSnapshotData = (try? JSONEncoder().encode(track.presetSnapshot)) ?? Data()
    }

    var track: Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            artworkData: artworkData,
            fileName: fileName,
            dateAdded: dateAdded,
            duration: duration,
            waveformSamples: [],
            isFavorite: isFavorite,
            lastPlayedAt: lastPlayedAt,
            presetSnapshot: (try? JSONDecoder().decode(TrackPresetSnapshot?.self, from: presetSnapshotData)) ?? nil
        )
    }
}

@Model
final class StoredPreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var pointsData: Data
    var effectsData: Data
    var isBuiltIn: Bool
    var categoryRawValue: String = PresetCategory.custom.rawValue
    var isFavorite: Bool = false
    var dateModified: Date

    init(preset: Preset) {
        id = preset.id
        name = preset.name
        pointsData = (try? JSONEncoder().encode(preset.points)) ?? Data()
        effectsData = (try? JSONEncoder().encode(preset.effects)) ?? Data()
        isBuiltIn = preset.isBuiltIn
        categoryRawValue = preset.category.rawValue
        isFavorite = preset.isFavorite
        dateModified = Date()
    }

    var preset: Preset {
        Preset(
            id: id,
            name: name,
            points: (try? JSONDecoder().decode([PresetPoint].self, from: pointsData)) ?? [],
            effects: (try? JSONDecoder().decode(PresetEffectSettings.self, from: effectsData)) ?? PresetEffectSettings(),
            isBuiltIn: isBuiltIn,
            category: PresetCategory(rawValue: categoryRawValue) ?? .custom,
            isFavorite: isFavorite
        )
    }
}

@Model
final class ProfileHistoryEntry {
    var id: UUID
    var presetName: String
    var effectsData: Data
    var createdAt: Date

    init(presetName: String, effects: PresetEffectSettings) {
        id = UUID()
        self.presetName = presetName
        effectsData = (try? JSONEncoder().encode(effects)) ?? Data()
        createdAt = Date()
    }
}
