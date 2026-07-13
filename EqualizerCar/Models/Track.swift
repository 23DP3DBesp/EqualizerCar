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

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case fileName
        case dateAdded
        case duration
        case waveformSamples
        case isFavorite
        case lastPlayedAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        dateAdded: Date = Date(),
        duration: Double = 0,
        waveformSamples: [Float] = [],
        isFavorite: Bool = false,
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.dateAdded = dateAdded
        self.duration = duration
        self.waveformSamples = waveformSamples
        self.isFavorite = isFavorite
        self.lastPlayedAt = lastPlayedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        fileName = try container.decode(String.self, forKey: .fileName)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        waveformSamples = try container.decodeIfPresent([Float].self, forKey: .waveformSamples) ?? []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
    }

    /// Собирает полный URL к файлу внутри папки приложения (Documents/Library).
    var fileURL: URL {
        LibraryManager.libraryFolderURL.appendingPathComponent(fileName)
    }
}
