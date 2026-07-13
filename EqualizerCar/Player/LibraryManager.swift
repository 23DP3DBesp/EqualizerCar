import Foundation
import Combine
import SwiftData

@MainActor
class LibraryManager: ObservableObject {
    enum RepeatMode: String, CaseIterable, Identifiable {
        case off = "Off"
        case one = "One"
        case all = "All"

        var id: String { rawValue }
    }

    @Published var tracks: [Track] = []
    @Published var importErrorMessage: String?
    @Published var isImporting = false
    @Published var searchText = ""
    @Published var queueIDs: [UUID] = []
    @Published var isShuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off

    private var modelContext: ModelContext?

    static var libraryFolderURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Library", isDirectory: true)
    }

    private var indexFileURL: URL {
        Self.libraryFolderURL.appendingPathComponent("index.json")
    }

    init() {
        createLibraryFolderIfNeeded()
        loadIndex()
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

        importSingleFile(from: sourceURL)
    }

    func importFiles(from sourceURLs: [URL]) {
        importErrorMessage = nil
        isImporting = true
        defer { isImporting = false }

        for sourceURL in sourceURLs {
            importSingleFile(from: sourceURL)
        }
    }

    private func importSingleFile(from sourceURL: URL) {
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
            tracks.append(newTrack)
            saveTrackToSwiftData(newTrack)
            saveIndex()
            precomputeWaveform(for: newTrack)
        } catch {
            let message = "Не удалось импортировать \(sourceURL.lastPathComponent): \(error.localizedDescription)"
            importErrorMessage = [previousErrorMessage, message].compactMap { $0 }.joined(separator: "\n")
            print("Ошибка копирования файла в библиотеку: \(error)")
        }
    }

    func deleteTrack(_ track: Track) {
        try? FileManager.default.removeItem(at: track.fileURL)
        tracks.removeAll { $0.id == track.id }
        queueIDs.removeAll { $0 == track.id }
        deleteTrackFromSwiftData(track)
        saveIndex()
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

    func play(_ track: Track, audioManager: AudioEngineManager) {
        audioManager.load(track: track)
        audioManager.play()
        markPlayed(track)
    }

    func addToQueue(_ track: Track) {
        queueIDs.append(track.id)
    }

    func clearQueue() {
        queueIDs.removeAll()
    }

    func playNext(audioManager: AudioEngineManager) {
        guard !tracks.isEmpty else { return }
        if repeatMode == .one, let id = audioManager.currentTrackID, let track = tracks.first(where: { $0.id == id }) {
            play(track, audioManager: audioManager)
            return
        }

        if let queuedID = queueIDs.first, let queuedTrack = tracks.first(where: { $0.id == queuedID }) {
            queueIDs.removeFirst()
            play(queuedTrack, audioManager: audioManager)
            return
        }

        if isShuffleEnabled, let randomTrack = tracks.randomElement() {
            play(randomTrack, audioManager: audioManager)
            return
        }

        guard let currentID = audioManager.currentTrackID,
              let currentIndex = tracks.firstIndex(where: { $0.id == currentID }) else {
            if let firstTrack = tracks.first { play(firstTrack, audioManager: audioManager) }
            return
        }

        let nextIndex = tracks.index(after: currentIndex)
        if nextIndex < tracks.endIndex {
            play(tracks[nextIndex], audioManager: audioManager)
        } else if repeatMode == .all, let firstTrack = tracks.first {
            play(firstTrack, audioManager: audioManager)
        }
    }

    func playPrevious(audioManager: AudioEngineManager) {
        guard !tracks.isEmpty else { return }
        if repeatMode == .one, let id = audioManager.currentTrackID, let track = tracks.first(where: { $0.id == id }) {
            play(track, audioManager: audioManager)
            return
        }

        guard let currentID = audioManager.currentTrackID,
              let currentIndex = tracks.firstIndex(where: { $0.id == currentID }) else {
            if let firstTrack = tracks.first { play(firstTrack, audioManager: audioManager) }
            return
        }

        if currentIndex > tracks.startIndex {
            let previousIndex = tracks.index(before: currentIndex)
            play(tracks[previousIndex], audioManager: audioManager)
        } else if repeatMode == .all, let lastTrack = tracks.last {
            play(lastTrack, audioManager: audioManager)
        }
    }

    var filteredTracks: [Track] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tracks }
        return tracks.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var favoriteTracks: [Track] {
        tracks.filter(\.isFavorite)
    }

    var recentlyPlayedTracks: [Track] {
        tracks
            .filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    func importMetadata(_ importedTracks: [Track]) {
        let existingIDs = Set(tracks.map(\.id))
        let availableTracks = importedTracks
            .filter { !existingIDs.contains($0.id) }
            .filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        guard !availableTracks.isEmpty else { return }

        tracks.append(contentsOf: availableTracks)
        availableTracks.forEach(saveTrackToSwiftData)
        saveIndex()
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

    private func precomputeWaveform(for track: Track) {
        let url = track.fileURL
        let id = track.id
        Task.detached(priority: .utility) {
            let samples = WaveformAnalyzer.samples(from: url)
            await MainActor.run {
                self.updateWaveform(trackID: id, samples: samples)
            }
        }
    }

    private func updateWaveform(trackID: UUID, samples: [Float]) {
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }
        let oldTrack = tracks[index]
        let updatedTrack = Track(
            id: oldTrack.id,
            title: oldTrack.title,
            fileName: oldTrack.fileName,
            dateAdded: oldTrack.dateAdded,
            duration: oldTrack.duration,
            waveformSamples: samples,
            isFavorite: oldTrack.isFavorite,
            lastPlayedAt: oldTrack.lastPlayedAt
        )
        tracks[index] = updatedTrack
        saveTrackToSwiftData(updatedTrack)
        saveIndex()
    }

    private func saveIndex() {
        do {
            let data = try JSONEncoder().encode(tracks)
            try data.write(to: indexFileURL)
        } catch {
            print("Ошибка сохранения индекса библиотеки: \(error)")
        }
    }

    private func loadIndex() {
        guard FileManager.default.fileExists(atPath: indexFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: indexFileURL)
            tracks = try JSONDecoder().decode([Track].self, from: data)
        } catch {
            print("Ошибка загрузки индекса библиотеки: \(error)")
        }
    }

    private func loadSwiftDataIndex() {
        guard let modelContext else { return }
        do {
            let descriptor = FetchDescriptor<StoredTrack>(sortBy: [SortDescriptor(\.dateAdded)])
            tracks = try modelContext.fetch(descriptor).map(\.track)
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
        tracks.forEach(saveTrackToSwiftData)
    }
}
