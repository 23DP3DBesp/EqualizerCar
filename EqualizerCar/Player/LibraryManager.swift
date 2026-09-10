import Foundation
import Combine
import SwiftData
import AVFoundation
import UIKit
import ImageIO

@MainActor
class LibraryManager: ObservableObject {
    enum SortOption: String, CaseIterable, Identifiable {
        case titleAscending = "Title A-Z"
        case titleDescending = "Title Z-A"
        case newestFirst = "Newest First"
        case oldestFirst = "Oldest First"
        case longestFirst = "Longest First"
        case shortestFirst = "Shortest First"
        case recentlyPlayed = "Recently Played"
        case favoritesFirst = "Favorites First"

        var id: String { rawValue }
    }

    enum RepeatMode: String, CaseIterable, Identifiable {
        case off = "Off"
        case one = "One"
        case all = "All"

        var id: String { rawValue }
    }

    enum PlaybackSource: Equatable {
        case library, favorites, recent, playlist(UUID), selection
    }

    @Published var browseSection = "All"
    @Published var browsePlaylistID: UUID?
    @Published private(set) var playbackSource: PlaybackSource = .library
    @Published private(set) var playbackIDs: [UUID] = []
    private var playbackHistory: [UUID] = []
    private var playbackQuery = ""

    @Published var tracks: [Track] = [] {
        didSet { rebuildTrackCaches() }
    }
    @Published var importErrorMessage: String?
    @Published private(set) var isLoadingLibrary = true
    @Published var isImporting = false
    @Published var searchText = "" {
        didSet { rebuildTrackCaches() }
    }
    @Published var queueIDs: [UUID] = []
    @Published var playlists: [AudioPlaylist] = [] { didSet { reconcilePlaybackQueue() } }
    @Published private(set) var filteredTracksCache: [Track] = []
    @Published private(set) var favoriteTracksCache: [Track] = []
    @Published private(set) var recentlyPlayedTracksCache: [Track] = []
    @Published var sortOption: SortOption {
        didSet {
            UserDefaults.standard.set(sortOption.rawValue, forKey: Self.sortOptionKey)
            rebuildTrackCaches()
        }
    }
    @Published var isShuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off
    @Published var perTrackPresetsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(perTrackPresetsEnabled, forKey: Self.perTrackPresetsEnabledKey)
        }
    }

    private let storageQueue = DispatchQueue(label: "EqualizerCar.library-storage", qos: .utility)
    private var pendingIndexWrite: DispatchWorkItem?
    private var metadataTask: Task<Void, Never>?
    private var pendingMetadataIDs = Set<UUID>()
    private var checkedMetadataIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "checkedAudioMetadata") ?? [])

    private var modelContext: ModelContext?
    private var trackIndexByID: [UUID: Track] = [:]
    private static let perTrackPresetsEnabledKey = "perTrackPresetsEnabled"
    private static let sortOptionKey = "librarySortOption"

    static var libraryFolderURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Library", isDirectory: true)
    }

    private var indexFileURL: URL {
        Self.libraryFolderURL.appendingPathComponent("index.json")
    }

    private var playlistsFileURL: URL {
        Self.libraryFolderURL.appendingPathComponent("playlists.json")
    }

    init() {
        perTrackPresetsEnabled = UserDefaults.standard.bool(forKey: Self.perTrackPresetsEnabledKey)
        let savedSortOption = UserDefaults.standard.string(forKey: Self.sortOptionKey)
        sortOption = savedSortOption.flatMap(SortOption.init(rawValue:)) ?? .titleAscending
        createLibraryFolderIfNeeded()
        let indexURL = indexFileURL
        let playlistURL = playlistsFileURL
        Task { [weak self] in
            let loaded = await Task.detached(priority: .userInitiated) {
                var loadedTracks: [Track] = []
                var loadedPlaylists: [AudioPlaylist] = []
                if FileManager.default.fileExists(atPath: indexURL.path) {
                    do { loadedTracks = try JSONDecoder().decode([Track].self, from: Data(contentsOf: indexURL)) }
                    catch { print("Ошибка загрузки библиотеки: \(error)") }
                }
                if FileManager.default.fileExists(atPath: playlistURL.path) {
                    do { loadedPlaylists = try JSONDecoder().decode([AudioPlaylist].self, from: Data(contentsOf: playlistURL)) }
                    catch { print("Ошибка загрузки плейлистов: \(error)") }
                }
                return (loadedTracks, loadedPlaylists)
            }.value
            guard let self else { return }
            playlists = loaded.1
            tracks = loaded.0
            isLoadingLibrary = false
            enqueueMetadata(tracks)
        }
    }

    private struct TrackMetadata: Sendable {
        let id: UUID
        var inspected = false
        var artist: String?
        var artwork: Data?
    }

    // AVAsset I/O and image decompression run away from the UI executor.
    private nonisolated static func readMetadata(id: UUID, url: URL) async -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        var result = TrackMetadata(id: id)
        guard let metadata = try? await asset.load(.commonMetadata) else { return result }
        result.inspected = true
        for item in metadata {
            if item.commonKey == .commonKeyArtist { result.artist = try? await item.load(.stringValue) }
            if item.commonKey == .commonKeyArtwork,
               let data = try? await item.load(.dataValue),
               let source = CGImageSourceCreateWithData(data as CFData, nil),
               let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                   kCGImageSourceCreateThumbnailFromImageAlways: true,
                   kCGImageSourceCreateThumbnailWithTransform: true,
                   kCGImageSourceThumbnailMaxPixelSize: 400
               ] as CFDictionary) {
                let output = NSMutableData()
                if let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
                    if CGImageDestinationFinalize(destination) { result.artwork = output as Data }
                }
            }
        }
        return result
    }

    private func enqueueMetadata(_ candidates: [Track]) {
        pendingMetadataIDs.formUnion(candidates.filter {
            !checkedMetadataIDs.contains($0.id.uuidString) && ($0.artist == nil || $0.artworkData == nil)
        }.map(\.id))
        guard metadataTask == nil, !pendingMetadataIDs.isEmpty else { return }
        metadataTask = Task { [weak self] in
            guard let self else { return }
            defer { metadataTask = nil }
            while !pendingMetadataIDs.isEmpty {
                let ids = Array(pendingMetadataIDs.prefix(24))
                pendingMetadataIDs.subtract(ids)
                let batch = self.tracks(for: ids).map { ($0.id, $0.fileURL) }
                let results = await Task.detached(priority: .utility) {
                    var results: [TrackMetadata] = []
                    for track in batch { results.append(await Self.readMetadata(id: track.0, url: track.1)) }
                    return results
                }.value
                var updated = tracks
                let indices = Dictionary(uniqueKeysWithValues: updated.enumerated().map { ($0.element.id, $0.offset) })
                var changed: [Track] = []
                for result in results {
                    if result.inspected { checkedMetadataIDs.insert(result.id.uuidString) }
                    guard let index = indices[result.id] else { continue }
                    var track = updated[index]
                    track.artist = result.artist ?? track.artist
                    track.artworkData = result.artwork ?? track.artworkData
                    if track != updated[index] { updated[index] = track; changed.append(track) }
                }
                if !changed.isEmpty {
                    tracks = updated
                    saveTracksToSwiftData(changed)
                    saveIndex()
                }
                UserDefaults.standard.set(Array(checkedMetadataIDs), forKey: "checkedAudioMetadata")
            }
        }
    }

    func configureModelContext(_ context: ModelContext) {
        modelContext = context
        loadSwiftDataIndex()
        if tracks.isEmpty {
            loadIndex()
            migrateJSONTracksToSwiftData()
        }
    }

    func importFile(from sourceURL: URL) {
        importErrorMessage = nil
        isImporting = true
        defer { isImporting = false }

        if let newTrack = importSingleFile(from: sourceURL) {
            tracks.append(newTrack)
            enqueueMetadata([newTrack])
            saveTrackToSwiftData(newTrack)
            saveIndex()
        }
    }

    func importFiles(from sourceURLs: [URL]) {
        importErrorMessage = nil
        isImporting = true
        defer { isImporting = false }

        var newTracks: [Track] = []
        for sourceURL in sourceURLs {
            if let newTrack = importSingleFile(from: sourceURL) {
                newTracks.append(newTrack)
            }
        }
        guard !newTracks.isEmpty else { return }
        tracks.append(contentsOf: newTracks)
        enqueueMetadata(newTracks)
        saveTracksToSwiftData(newTracks)
        saveIndex()
    }

    private func importSingleFile(from sourceURL: URL) -> Track? {
        let previousErrorMessage = importErrorMessage

        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let originalName = sourceURL.lastPathComponent
        let uniqueFileName = "\(UUID().uuidString)_\(originalName)"
        let destinationURL = Self.libraryFolderURL.appendingPathComponent(uniqueFileName)

        do {
            try copyImportedFile(from: sourceURL, to: destinationURL)
            let title = originalName.replacingOccurrences(of: ".\(sourceURL.pathExtension)", with: "")
            let newTrack = Track(
                title: title,
                fileName: uniqueFileName,
                duration: WaveformAnalyzer.duration(from: destinationURL),
                waveformSamples: []
            )
            return newTrack
        } catch {
            let message = "Не удалось импортировать \(sourceURL.lastPathComponent): \(error.localizedDescription)"
            importErrorMessage = [previousErrorMessage, message].compactMap { $0 }.joined(separator: "\n")
            print("Ошибка копирования файла в библиотеку: \(error)")
            return nil
        }
    }

    func deleteTrack(_ track: Track) {
        try? FileManager.default.removeItem(at: track.fileURL)
        tracks.removeAll { $0.id == track.id }
        queueIDs.removeAll { $0 == track.id }
        removeTrackFromAllPlaylists(track.id)
        deleteTrackFromSwiftData(track)
        saveIndex()
    }

    func deleteAllTracks() {
        for track in tracks {
            try? FileManager.default.removeItem(at: track.fileURL)
            deleteTrackFromSwiftData(track)
        }
        tracks.removeAll()
        queueIDs.removeAll()
        playlists = playlists.map { playlist in
            var updatedPlaylist = playlist
            updatedPlaylist.trackIDs.removeAll()
            updatedPlaylist.updatedAt = Date()
            return updatedPlaylist
        }
        saveIndex()
        savePlaylists()
    }

    func renameTrack(_ track: Track, title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        tracks[index].title = cleanTitle
        saveTrackToSwiftData(tracks[index])
        saveIndex()
    }

    func toggleFavorite(_ track: Track) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        tracks[index].isFavorite.toggle()
        saveTrackToSwiftData(tracks[index])
        saveIndex()
    }

    func markPlayed(_ track: Track) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        tracks[index].lastPlayedAt = Date()
        saveTrackToSwiftData(tracks[index])
        saveIndex()
    }

    /// Selecting a collection replaces its ordered playback scope, including empty lists.
    func selectPlaybackSource(_ source: PlaybackSource, tracks selection: [Track], query: String = "") {
        var seen = Set<UUID>()
        let ids = selection.map(\.id).filter { trackIndexByID[$0] != nil && seen.insert($0).inserted }
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source != playbackSource || ids != playbackIDs || playbackQuery != cleanQuery else { return }
        playbackQuery = cleanQuery
        playbackSource = source
        playbackIDs = ids
        queueIDs.removeAll()
        playbackHistory.removeAll()
    }

    private func reconcilePlaybackQueue() {
        let scopeIDs = Set(playbackIDs)
        let members: [Track]
        switch playbackSource {
        case .library: members = playbackIDs.isEmpty ? sortedTracks(tracks) : tracks
        case .selection: members = tracks.filter { scopeIDs.contains($0.id) }
        case .favorites: members = tracks.filter(\.isFavorite)
        case .recent: members = tracks.filter { $0.lastPlayedAt != nil }
        case .playlist(let id): members = self.tracks(for: playlists.first { $0.id == id }?.trackIDs ?? [])
        }
        let allowedIDs = members.filter {
            playbackQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(playbackQuery)
        }.map(\.id)
        let allowed = Set(allowedIDs)
        var reconciled = playbackIDs.filter { allowed.contains($0) }
        // Metadata writes must not reorder a playing list, especially Recently Played.
        let existing = Set(reconciled)
        reconciled.append(contentsOf: allowedIDs.filter { !existing.contains($0) })
        if playbackIDs != reconciled { playbackIDs = reconciled }
        let validIDs = Set(reconciled)
        let pending = queueIDs.filter { validIDs.contains($0) }
        if queueIDs != pending { queueIDs = pending }
        playbackHistory.removeAll { !validIDs.contains($0) }
    }

    func play(_ track: Track, audioManager: AudioEngineManager) {
        // Legacy single-track callers must never fall through into the entire library.
        if !playbackIDs.contains(track.id) {
            selectPlaybackSource(.selection, tracks: [track])
        }
        persistCurrentTrackPresetIfNeeded(audioManager: audioManager)
        audioManager.load(track: track)
        if perTrackPresetsEnabled, let snapshot = track.presetSnapshot {
            audioManager.applyTrackPresetSnapshot(snapshot)
        }
        audioManager.play()
        markPlayed(track)
    }

    func saveCurrentPresetForCurrentTrack(audioManager: AudioEngineManager) {
        guard let currentTrackID = audioManager.currentTrackID else { return }
        savePresetSnapshot(audioManager.currentTrackPresetSnapshot(), for: currentTrackID)
    }

    func addToQueue(_ track: Track) {
        guard playbackIDs.contains(track.id), !queueIDs.contains(track.id) else { return }
        queueIDs.append(track.id)
    }

    func clearQueue() {
        queueIDs.removeAll()
    }

    func createPlaylist(named name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        playlists.append(AudioPlaylist(name: cleanName))
        savePlaylists()
    }

    func renamePlaylist(_ playlist: AudioPlaylist, name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty,
              let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = cleanName
        playlists[index].updatedAt = Date()
        savePlaylists()
    }

    func deletePlaylist(_ playlist: AudioPlaylist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }

    func addToPlaylist(_ track: Track, playlist: AudioPlaylist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }),
              !playlists[index].trackIDs.contains(track.id) else { return }
        playlists[index].trackIDs.append(track.id)
        playlists[index].updatedAt = Date()
        savePlaylists()
    }

    func removeFromPlaylist(_ track: Track, playlist: AudioPlaylist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].trackIDs.removeAll { $0 == track.id }
        playlists[index].updatedAt = Date()
        savePlaylists()
    }

    func playNext(audioManager: AudioEngineManager, automatically: Bool = false) {
        reconcilePlaybackQueue()
        let candidates = tracks(for: playbackIDs)
        guard !candidates.isEmpty else {
            if automatically { audioManager.pause() }
            return
        }
        let currentID = audioManager.currentTrackID
        if automatically, repeatMode == .one,
           let track = candidates.first(where: { $0.id == currentID }) {
            play(track, audioManager: audioManager)
            return
        }
        var next: Track?
        if !queueIDs.isEmpty {
            next = track(with: queueIDs.removeFirst())
        } else if isShuffleEnabled {
            let playedIDs = Set(playbackHistory)
            let remaining = candidates.filter { $0.id != currentID && !playedIDs.contains($0.id) }
            next = remaining.randomElement()
            if next == nil, repeatMode == .all {
                playbackHistory.removeAll()
                next = candidates.filter { $0.id != currentID }.randomElement() ?? candidates.first
            }
        } else if let index = candidates.firstIndex(where: { $0.id == currentID }) {
            if index + 1 < candidates.count { next = candidates[index + 1] }
            else if repeatMode == .all { next = candidates.first }
        } else {
            next = candidates.first
        }
        if let next {
            if let currentID, playbackIDs.contains(currentID) { playbackHistory.append(currentID) }
            play(next, audioManager: audioManager)
        } else if automatically {
            audioManager.pause()
        }
    }

    func playPrevious(audioManager: AudioEngineManager) {
        reconcilePlaybackQueue()
        let candidates = tracks(for: playbackIDs)
        guard !candidates.isEmpty else { return }
        if isShuffleEnabled, let previousID = playbackHistory.popLast(), let previous = track(with: previousID) {
            play(previous, audioManager: audioManager)
            return
        }
        guard let index = candidates.firstIndex(where: { $0.id == audioManager.currentTrackID }) else {
            play(candidates[0], audioManager: audioManager)
            return
        }
        if index > 0 { play(candidates[index - 1], audioManager: audioManager) }
        else if repeatMode == .all, let last = candidates.last { play(last, audioManager: audioManager) }
    }

    var filteredTracks: [Track] { filteredTracksCache }

    var favoriteTracks: [Track] { favoriteTracksCache }

    var recentlyPlayedTracks: [Track] { recentlyPlayedTracksCache }

    func track(with id: UUID) -> Track? {
        trackIndexByID[id]
    }

    func tracks(for ids: [UUID]) -> [Track] {
        ids.compactMap { trackIndexByID[$0] }
    }

    private func rebuildTrackCaches() {
        trackIndexByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingTracks: [Track]
        if query.isEmpty {
            matchingTracks = tracks
        } else {
            matchingTracks = tracks.filter { $0.title.localizedCaseInsensitiveContains(query) }
        }
        reconcilePlaybackQueue()
        filteredTracksCache = sortedTracks(matchingTracks)
        favoriteTracksCache = tracks.filter(\.isFavorite)
        recentlyPlayedTracksCache = tracks
            .filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    func importMetadata(_ importedTracks: [Track]) {
        let existingIDs = Set(tracks.map(\.id))
        let availableTracks = importedTracks
            .filter { !existingIDs.contains($0.id) }
            .filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
            .map(sanitizedTrack)
        guard !availableTracks.isEmpty else { return }

        tracks.append(contentsOf: availableTracks)
        saveTracksToSwiftData(availableTracks)
        saveIndex()
    }

    func importPlaylists(_ importedPlaylists: [AudioPlaylist]) {
        guard !importedPlaylists.isEmpty else { return }
        let existingIDs = Set(playlists.map(\.id))
        let availableTrackIDs = Set(tracks.map(\.id))
        let newPlaylists = importedPlaylists
            .filter { !existingIDs.contains($0.id) }
            .map { playlist in
                var sanitizedPlaylist = playlist
                sanitizedPlaylist.trackIDs = playlist.trackIDs.filter { availableTrackIDs.contains($0) }
                return sanitizedPlaylist
            }
        guard !newPlaylists.isEmpty else { return }
        playlists.append(contentsOf: newPlaylists)
        savePlaylists()
    }

    func exportedAudioFiles() -> [String: Data] {
        var files: [String: Data] = [:]
        for track in tracks {
            guard FileManager.default.fileExists(atPath: track.fileURL.path) else { continue }
            do {
                files[track.fileName] = try Data(contentsOf: track.fileURL)
            } catch {
                print("Ошибка чтения аудиофайла для backup: \(error)")
            }
        }
        return files
    }

    func restoreAudioFiles(_ files: [String: Data]) {
        guard !files.isEmpty else { return }
        createLibraryFolderIfNeeded()

        for (fileName, data) in files {
            let destinationURL = Self.libraryFolderURL.appendingPathComponent(fileName)
            guard !FileManager.default.fileExists(atPath: destinationURL.path) else { continue }
            do {
                try data.write(to: destinationURL, options: .atomic)
            } catch {
                print("Ошибка восстановления аудиофайла из backup: \(error)")
            }
        }
    }

    private func createLibraryFolderIfNeeded() {
        let folder = Self.libraryFolderURL
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    private func copyImportedFile(from sourceURL: URL, to destinationURL: URL) throws {
        createLibraryFolderIfNeeded()
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: sourceURL, options: [], error: &coordinatorError) { readableURL in
            do {
                try FileManager.default.copyItem(at: readableURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        if copyError == nil, coordinatorError == nil, FileManager.default.fileExists(atPath: destinationURL.path) {
            return
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        let data = try Data(contentsOf: sourceURL)
        try data.write(to: destinationURL, options: .atomic)
    }

    private func sortedTracks(_ tracks: [Track]) -> [Track] {
        switch sortOption {
        case .titleAscending:
            return tracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .titleDescending:
            return tracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
        case .newestFirst:
            return tracks.sorted { $0.dateAdded > $1.dateAdded }
        case .oldestFirst:
            return tracks.sorted { $0.dateAdded < $1.dateAdded }
        case .longestFirst:
            return tracks.sorted { $0.duration > $1.duration }
        case .shortestFirst:
            return tracks.sorted { $0.duration < $1.duration }
        case .recentlyPlayed:
            return tracks.sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
        case .favoritesFirst:
            return tracks.sorted {
                if $0.isFavorite != $1.isFavorite {
                    return $0.isFavorite && !$1.isFavorite
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
    }

    private func removeTrackFromAllPlaylists(_ trackID: UUID) {
        var didChange = false
        playlists = playlists.map { playlist in
            var updatedPlaylist = playlist
            let oldCount = updatedPlaylist.trackIDs.count
            updatedPlaylist.trackIDs.removeAll { $0 == trackID }
            if oldCount != updatedPlaylist.trackIDs.count {
                updatedPlaylist.updatedAt = Date()
                didChange = true
            }
            return updatedPlaylist
        }
        if didChange {
            savePlaylists()
        }
    }

    private func persistCurrentTrackPresetIfNeeded(audioManager: AudioEngineManager) {
        guard perTrackPresetsEnabled else { return }
        saveCurrentPresetForCurrentTrack(audioManager: audioManager)
    }

    private func savePresetSnapshot(_ snapshot: TrackPresetSnapshot, for trackID: UUID) {
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }
        let oldTrack = tracks[index]
        let updatedTrack = Track(
            id: oldTrack.id,
            title: oldTrack.title,
            artist: oldTrack.artist,
            artworkData: oldTrack.artworkData,
            fileName: oldTrack.fileName,
            dateAdded: oldTrack.dateAdded,
            duration: oldTrack.duration,
            waveformSamples: oldTrack.waveformSamples,
            isFavorite: oldTrack.isFavorite,
            lastPlayedAt: oldTrack.lastPlayedAt,
            presetSnapshot: snapshot
        )
        tracks[index] = updatedTrack
        saveTrackToSwiftData(updatedTrack)
        saveIndex()
    }

    private func saveIndex() {
        guard !isLoadingLibrary else { return }
        pendingIndexWrite?.cancel()
        let snapshot = tracks
        let destination = indexFileURL
        let work = DispatchWorkItem {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: destination, options: .atomic)
            } catch {
                print("Ошибка сохранения индекса библиотеки: \(error)")
            }
        }
        pendingIndexWrite = work
        storageQueue.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    /// Called only when the app leaves the foreground, so the latest snapshot reaches disk.
    func flushPendingStorage() {
        guard !isLoadingLibrary else { return }
        pendingIndexWrite?.cancel()
        let snapshot = tracks
        let destination = indexFileURL
        storageQueue.sync {
            do { try JSONEncoder().encode(snapshot).write(to: destination, options: .atomic) }
            catch { print("Ошибка сохранения индекса библиотеки: \(error)") }
        }
        pendingIndexWrite = nil
    }

    private func loadIndex() {
        guard FileManager.default.fileExists(atPath: indexFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: indexFileURL)
            tracks = try JSONDecoder().decode([Track].self, from: data).map(sanitizedTrack)
        } catch {
            print("Ошибка загрузки индекса библиотеки: \(error)")
        }
    }

    private func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            try data.write(to: playlistsFileURL)
        } catch {
            print("Ошибка сохранения плейлистов: \(error)")
        }
    }

    private func loadPlaylists() {
        guard FileManager.default.fileExists(atPath: playlistsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: playlistsFileURL)
            playlists = try JSONDecoder().decode([AudioPlaylist].self, from: data)
        } catch {
            print("Ошибка загрузки плейлистов: \(error)")
        }
    }

    private func loadSwiftDataIndex() {
        guard let modelContext else { return }
        do {
            let descriptor = FetchDescriptor<StoredTrack>(sortBy: [SortDescriptor(\.dateAdded)])
            tracks = try modelContext.fetch(descriptor).map(\.track).map(sanitizedTrack)
        } catch {
            print("Ошибка загрузки SwiftData библиотеки: \(error)")
        }
    }

    private func saveTrackToSwiftData(_ track: Track) {
        guard let modelContext else { return }
        do {
            let id = track.id
            let descriptor = FetchDescriptor<StoredTrack>(predicate: #Predicate { $0.id == id })
            for existingTrack in try modelContext.fetch(descriptor) {
                modelContext.delete(existingTrack)
            }
            modelContext.insert(StoredTrack(track: track))
            try modelContext.save()
        } catch {
            print("Ошибка сохранения SwiftData трека: \(error)")
        }
    }

    private func saveTracksToSwiftData(_ tracks: [Track]) {
        guard let modelContext, !tracks.isEmpty else { return }
        do {
            for track in tracks {
                let id = track.id
                let descriptor = FetchDescriptor<StoredTrack>(predicate: #Predicate { $0.id == id })
                for existingTrack in try modelContext.fetch(descriptor) {
                    modelContext.delete(existingTrack)
                }
                modelContext.insert(StoredTrack(track: track))
            }
            try modelContext.save()
        } catch {
            print("Ошибка пакетного сохранения SwiftData треков: \(error)")
        }
    }

    private func deleteTrackFromSwiftData(_ track: Track) {
        guard let modelContext else { return }
        do {
            let id = track.id
            let descriptor = FetchDescriptor<StoredTrack>(predicate: #Predicate { $0.id == id })
            for storedTrack in try modelContext.fetch(descriptor) {
                modelContext.delete(storedTrack)
            }
            try modelContext.save()
        } catch {
            print("Ошибка удаления SwiftData трека: \(error)")
        }
    }

    private func migrateJSONTracksToSwiftData() {
        guard modelContext != nil else { return }
        saveTracksToSwiftData(tracks)
    }

    private func sanitizedTrack(_ track: Track) -> Track {
        guard !track.waveformSamples.isEmpty else { return track }
        return Track(
            id: track.id,
            title: track.title,
            artist: track.artist,
            artworkData: track.artworkData,
            fileName: track.fileName,
            dateAdded: track.dateAdded,
            duration: track.duration,
            waveformSamples: [],
            isFavorite: track.isFavorite,
            lastPlayedAt: track.lastPlayedAt,
            presetSnapshot: track.presetSnapshot
        )
    }
}
