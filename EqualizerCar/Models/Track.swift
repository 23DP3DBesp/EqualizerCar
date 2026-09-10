//
//  Track.swift
//  EqualizerCar
//
//  Created by Денис Беспалов on 08/07/2026.
//

import Foundation


/// Модель одного трека в библиотеке.
/// Identifiable нужен для использования в SwiftUI List/ForEach.
/// Codable нужен, чтобы сохранять список треков на диск (JSON).
struct Track: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var artist: String?
    var artworkData: Data?
    var artistDisplayName: String { artist?.isEmpty == false ? artist! : "Unknown artist" }
    var title: String
    // Храним только имя файла (не полный путь!), т.к. полный путь
    // к Documents может меняться между запусками приложения на
    // разных устройствах/симуляторах. Полный URL собираем на лету.
    let fileName: String
    let dateAdded: Date
    let duration: Double
    let waveformSamples: [Float]
    var isFavorite: Bool
    var lastPlayedAt: Date?
    var presetSnapshot: TrackPresetSnapshot?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case artworkData
        case fileName
        case dateAdded
        case duration
        case waveformSamples
        case isFavorite
        case lastPlayedAt
        case presetSnapshot
    }

    init(
        id: UUID = UUID(),
        title: String,
        artist: String? = nil,
        artworkData: Data? = nil,
        fileName: String,
        dateAdded: Date = Date(),
        duration: Double = 0,
        waveformSamples: [Float] = [],
        isFavorite: Bool = false,
        lastPlayedAt: Date? = nil,
        presetSnapshot: TrackPresetSnapshot? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkData = artworkData
        self.fileName = fileName
        self.dateAdded = dateAdded
        self.duration = duration
        self.waveformSamples = waveformSamples
        self.isFavorite = isFavorite
        self.lastPlayedAt = lastPlayedAt
        self.presetSnapshot = presetSnapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        artworkData = try container.decodeIfPresent(Data.self, forKey: .artworkData)
        fileName = try container.decode(String.self, forKey: .fileName)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        // Legacy indexes could contain large waveform arrays per track. Do not decode them on launch.
        waveformSamples = []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        presetSnapshot = try container.decodeIfPresent(TrackPresetSnapshot.self, forKey: .presetSnapshot)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(artworkData, forKey: .artworkData)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(duration, forKey: .duration)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(lastPlayedAt, forKey: .lastPlayedAt)
        try container.encodeIfPresent(presetSnapshot, forKey: .presetSnapshot)
    }

    /// Собирает полный URL к файлу внутри папки приложения (Documents/Library).
    var fileURL: URL {
        LibraryManager.libraryFolderURL.appendingPathComponent(fileName)
    }
}

struct TrackPresetSnapshot: Codable, Equatable, Sendable {
    var bandCount: Int
    var points: [PresetPoint]
    var effects: PresetEffectSettings
    var savedAt: Date

    init(
        bandCount: Int,
        points: [PresetPoint],
        effects: PresetEffectSettings,
        savedAt: Date = Date()
    ) {
        self.bandCount = bandCount
        self.points = points
        self.effects = effects
        self.savedAt = savedAt
    }
}
