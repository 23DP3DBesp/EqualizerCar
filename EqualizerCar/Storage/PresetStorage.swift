import Foundation

struct PresetStorage {
    private var userPresetsFileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("user_presets.json")
    }

    func loadUserPresets() -> [Preset] {
        guard FileManager.default.fileExists(atPath: userPresetsFileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: userPresetsFileURL)
            return try JSONDecoder().decode([Preset].self, from: data)
        } catch {
            print("Ошибка загрузки пресетов: \(error)")
            return []
        }
    }

    func saveUserPresets(_ presets: [Preset]) {
        do {
            let userOnly = presets.filter { !$0.isBuiltIn }
            let data = try JSONEncoder().encode(userOnly)
            try data.write(to: userPresetsFileURL)
        } catch {
            print("Ошибка сохранения пресетов: \(error)")
        }
    }

    func exportUserPresets(_ presets: [Preset]) -> Data {
        do {
            let userOnly = presets.filter { !$0.isBuiltIn }
            return try JSONEncoder().encode(userOnly)
        } catch {
            print("Ошибка экспорта пресетов: \(error)")
            return Data()
        }
    }

    func decodeImportedPresets(from data: Data) -> [Preset] {
        do {
            return try JSONDecoder().decode([Preset].self, from: data)
        } catch {
            print("Ошибка импорта пресетов: \(error)")
            return []
        }
    }
}
