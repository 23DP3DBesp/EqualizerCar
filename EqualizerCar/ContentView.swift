import SwiftUI
import UniformTypeIdentifiers

struct PresetExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ContentView: View {
    private enum ActiveImporter {
        case track
        case preset
        case backup

        var allowedContentTypes: [UTType] {
            switch self {
            case .track:
                return [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
            case .preset, .backup:
                return [.json]
            }
        }
    }

    @StateObject private var audioManager = AudioEngineManager()
    @StateObject private var library = LibraryManager()
    @StateObject private var presetManager = PresetManager()
    @Environment(\.scenePhase) private var scenePhase

    @State private var activeImporter: ActiveImporter?
    @State private var isImporterPresented = false
    @State private var showPresetExporter = false
    @State private var showBackupExporter = false
    @State private var presetExportDocument = PresetExportDocument()
    @State private var backupExportDocument = AppBackupDocument()
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""

    var body: some View {
        TabView {
            NavigationStack {
                GlassPlayerView()
                    .environmentObject(audioManager)
            }
            .tabItem {
                Label("Player", systemImage: "play.circle.fill")
            }

            NavigationStack {
                EqualizerTabView(audioManager: audioManager)
            }
            .tabItem {
                Label("EQ", systemImage: "slider.horizontal.3")
            }

            NavigationStack {
                ScrollView {
                    EffectsPanelView(audioManager: audioManager)
                        .padding(.vertical, 20)
                }
                .navigationTitle("Effects")
            }
            .tabItem {
                Label("Effects", systemImage: "dial.high.fill")
            }

            NavigationStack {
                PresetsPanelView(
                    audioManager: audioManager,
                    presetManager: presetManager,
                    showSavePresetAlert: $showSavePresetAlert,
                    importAction: { presentImporter(.preset) },
                    exportAction: exportPresets
                )
            }
            .tabItem {
                Label("Presets", systemImage: "square.grid.2x2.fill")
            }

            NavigationStack {
                LibraryPanelView(
                    audioManager: audioManager,
                    library: library,
                    showFilePicker: Binding(
                        get: { isImporterPresented && activeImporter == .track },
                        set: { isPresented in
                            if isPresented {
                                presentImporter(.track)
                            } else {
                                isImporterPresented = false
                            }
                        }
                    ),
                    importBackupAction: { presentImporter(.backup) },
                    exportBackupAction: exportBackup
                )
            }
            .tabItem {
                Label("Library", systemImage: "music.note.list")
            }
        }
        .preferredColorScheme(.light)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: activeImporter?.allowedContentTypes ?? [.data],
            allowsMultipleSelection: activeImporter == .track
        ) { result in
            let importer = activeImporter
            activeImporter = nil
            isImporterPresented = false

            switch result {
            case .success(let urls):
                switch importer {
                case .track:
                    library.importFiles(from: urls)
                case .preset:
                    guard let url = urls.first else { return }
                    importPresets(from: url)
                case .backup:
                    guard let url = urls.first else { return }
                    importBackup(from: url)
                case .none:
                    break
                }
            case .failure(let error):
                print("Ошибка выбора файла: \(error)")
            }
        }
        .fileExporter(
            isPresented: $showPresetExporter,
            document: presetExportDocument,
            contentType: .json,
            defaultFilename: "EqualizerCar Presets"
        ) { result in
            if case .failure(let error) = result {
                print("Ошибка экспорта пресетов: \(error)")
            }
        }
        .fileExporter(
            isPresented: $showBackupExporter,
            document: backupExportDocument,
            contentType: .json,
            defaultFilename: "EqualizerCar Backup"
        ) { result in
            if case .failure(let error) = result {
                print("Ошибка экспорта backup: \(error)")
            }
        }
        .alert("Сохранить пресет", isPresented: $showSavePresetAlert) {
            TextField("Название пресета", text: $newPresetName)
            Button("Отмена", role: .cancel) {
                newPresetName = ""
            }
            Button("Сохранить") {
                guard !newPresetName.isEmpty else { return }
                presetManager.saveCurrentAsPreset(name: newPresetName, audioManager: audioManager)
                newPresetName = ""
            }
        }
        .onAppear {
            audioManager.playbackFinished = { [weak audioManager, weak library] in
                guard let audioManager, let library else { return }
                library.playNext(audioManager: audioManager)
            }
            audioManager.nextTrackRequested = { [weak audioManager, weak library] in
                guard let audioManager, let library else { return }
                library.playNext(audioManager: audioManager)
            }
            audioManager.previousTrackRequested = { [weak audioManager, weak library] in
                guard let audioManager, let library else { return }
                library.playPrevious(audioManager: audioManager)
            }
            audioManager.startLevelMetering()
        }
        .onDisappear {
            audioManager.playbackFinished = nil
            audioManager.nextTrackRequested = nil
            audioManager.previousTrackRequested = nil
            audioManager.stopLevelMetering()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                audioManager.startLevelMetering()
            case .background:
                audioManager.stopLevelMetering()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    private func presentImporter(_ importer: ActiveImporter) {
        activeImporter = importer
        isImporterPresented = true
    }

    private func exportPresets() {
        presetExportDocument = PresetExportDocument(data: presetManager.exportUserPresetsData())
        showPresetExporter = true
    }

    private func exportBackup() {
        backupExportDocument = AppBackupDocument(backup: AppBackup(
            tracks: library.tracks,
            audioFiles: library.exportedAudioFiles(),
            userPresets: presetManager.userPresets(),
            currentEffects: audioManager.currentEffectSettings(),
            exportedAt: Date()
        ))
        showBackupExporter = true
    }

    private func importPresets(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Нет доступа к файлу пресетов")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            presetManager.importUserPresets(from: data)
        } catch {
            print("Ошибка чтения файла пресетов: \(error)")
        }
    }

    private func importBackup(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Нет доступа к backup-файлу")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let backup = try JSONDecoder().decode(AppBackup.self, from: data)
            library.restoreAudioFiles(backup.audioFiles)
            library.importMetadata(backup.tracks)
            presetManager.importUserPresets(from: try JSONEncoder().encode(backup.userPresets))
            audioManager.applyEffects(backup.currentEffects)
        } catch {
            print("Ошибка импорта backup: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
