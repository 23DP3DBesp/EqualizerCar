import Foundation

@MainActor
struct BackupService {
    static func saveBackup(toFolderNamed folderName: String = "Backups", library: LibraryManager, presets: PresetManager, audioManager: AudioEngineManager) -> URL? {
        let backupsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: backupsFolder.path) {
            try? FileManager.default.createDirectory(at: backupsFolder, withIntermediateDirectories: true)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let fileName = "EqualizerCarBackup_\(timestamp).json"
        let destination = backupsFolder.appendingPathComponent(fileName)

        let tracks = library.tracks
        let audioFiles = library.exportedAudioFiles()
        let userPresets = presets.userPresets()
        let currentEffects = audioManager.currentEffectSettings()

        let backup = AppBackup(tracks: tracks, audioFiles: audioFiles, userPresets: userPresets, currentEffects: currentEffects, exportedAt: Date())

        do {
            let data = try JSONEncoder().encode(backup)
            try data.write(to: destination, options: .atomic)
            return destination
        } catch {
            print("Ошибка сохранения backup: \(error)")
            return nil
        }
    }
}
