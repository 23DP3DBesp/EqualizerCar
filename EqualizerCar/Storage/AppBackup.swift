import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct AppBackup: Codable, Sendable {
    var tracks: [Track]
    var audioFiles: [String: Data]
    var userPresets: [Preset]
    var currentEffects: PresetEffectSettings
    var exportedAt: Date

    private enum CodingKeys: String, CodingKey {
        case tracks
        case audioFiles
        case userPresets
        case currentEffects
        case exportedAt
    }

    nonisolated init(
        tracks: [Track],
        audioFiles: [String: Data] = [:],
        userPresets: [Preset],
        currentEffects: PresetEffectSettings,
        exportedAt: Date
    ) {
        self.tracks = tracks
        self.audioFiles = audioFiles
        self.userPresets = userPresets
        self.currentEffects = currentEffects
        self.exportedAt = exportedAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tracks = try container.decode([Track].self, forKey: .tracks)
        audioFiles = try container.decodeIfPresent([String: Data].self, forKey: .audioFiles) ?? [:]
        userPresets = try container.decode([Preset].self, forKey: .userPresets)
        currentEffects = try container.decode(PresetEffectSettings.self, forKey: .currentEffects)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(audioFiles, forKey: .audioFiles)
        try container.encode(userPresets, forKey: .userPresets)
        try container.encode(currentEffects, forKey: .currentEffects)
        try container.encode(exportedAt, forKey: .exportedAt)
    }
}

struct AppBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var backup: AppBackup

    init(backup: AppBackup = AppBackup(tracks: [], userPresets: [], currentEffects: PresetEffectSettings(), exportedAt: Date())) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        backup = try JSONDecoder().decode(AppBackup.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(backup)
        return FileWrapper(regularFileWithContents: data)
    }
}
