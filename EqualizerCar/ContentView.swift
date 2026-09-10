import SwiftUI
import Combine
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

    // The navigation owns the engine without observing every effect-slider change.
    @StateObject private var audioOwner = AudioEngineOwner()
    private var audioManager: AudioEngineManager { audioOwner.manager }
    @StateObject private var library = LibraryManager()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTab = 0

    @State private var activeImporter: ActiveImporter?
    @State private var isImporterPresented = false
    @State private var showPresetExporter = false
    @State private var showBackupExporter = false
    @State private var presetExportDocument = PresetExportDocument()
    @State private var backupExportDocument = AppBackupDocument()
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""

    var body: some View {
        HStack(spacing: 0) {
            if sizeClass == .regular { sidebar }
            TabView(selection: $selectedTab) {
            NavigationStack {
                PlayerHomeView(
                    audioManager: audioManager,
                    library: library,
                    presetManager: presetManager,
                    addMusicAction: { presentImporter(.track) },
                    openLibraryAction: { selectedTab = 1 }
                )
            }
            .miniPlayerInset(audioManager: audioManager, library: library, presetManager: presetManager)
            .tabItem {
                Label("Player", systemImage: "play.circle.fill")
            }
            .tag(0)

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
                    )
                )
            }
            .miniPlayerInset(audioManager: audioManager, library: library, presetManager: presetManager)
            .tabItem {
                Label("Library", systemImage: "music.note.list")
            }
            .tag(1)

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EqualizerTabView(audioManager: audioManager, isEmbedded: true)
                        EffectsPanelView(audioManager: audioManager)
                    }
                    .padding(20)
                }
                .background(themeManager.current.screenBackground.ignoresSafeArea())
                .navigationTitle("Effects")
            }
            .miniPlayerInset(audioManager: audioManager, library: library, presetManager: presetManager)
            .tabItem {
                Label("Effects", systemImage: "dial.high.fill")
            }
            .tag(2)

            NavigationStack {
                List {
                    Section("Sound") {
                        NavigationLink("Bass Lab") { BassLabView(audioManager: audioManager) }
                        NavigationLink("Presets") {
                            PresetsPanelView(audioManager: audioManager, presetManager: presetManager,
                                showSavePresetAlert: $showSavePresetAlert,
                                importAction: { presentImporter(.preset) }, exportAction: exportPresets)
                        }
                    }
                    Section("Tools") {
                        NavigationLink("Car Tools") {
                            LegacyCarToolsView(audioManager: audioManager, library: library, presetManager: presetManager)
                        }
                        NavigationLink("Drive Mode") {
                            DriveModeView(audioManager: audioManager, library: library,
                                presetManager: presetManager, addMusicAction: { presentImporter(.track) })
                        }
                        NavigationLink("Settings") {
                            SettingsPanelView(audioManager: audioManager, library: library,
                                importBackupAction: { presentImporter(.backup) }, exportBackupAction: exportBackup)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.white)
                .navigationTitle("More")
            }
            .miniPlayerInset(audioManager: audioManager, library: library, presetManager: presetManager)
            .tabItem { Label("More", systemImage: "ellipsis") }
            .tag(3)
        }
            .toolbar(sizeClass == .regular ? .hidden : .visible, for: .tabBar)
        }
        .disabled(library.isLoadingLibrary)
        .overlay {
            if library.isLoadingLibrary {
                ProgressView("Loading library…").padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .preferredColorScheme(.light)
        .carAmbientTheme(themeManager)
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
                library.playNext(audioManager: audioManager, automatically: true)
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
            if library.perTrackPresetsEnabled {
                library.saveCurrentPresetForCurrentTrack(audioManager: audioManager)
            }
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
                if library.perTrackPresetsEnabled {
                    library.saveCurrentPresetForCurrentTrack(audioManager: audioManager)
                }
                library.flushPendingStorage()
                audioManager.stopLevelMetering()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("EqualizerCar", systemImage: "waveform")
                .font(.title3.weight(.bold)).padding(.vertical, 28)
            sidebarItem("Home", icon: "house", tab: 0)
            sidebarItem("Library", icon: "music.note.list", tab: 1, section: "All")
            sidebarItem("Favorites", icon: "heart", tab: 1, section: "Favorites")
            sidebarItem("Recently Played", icon: "clock", tab: 1, section: "Recent")
            sidebarItem("Playlists", icon: "square.stack", tab: 1, section: "Playlists")
            Divider().padding(.vertical, 14)
            sidebarItem("Effects", icon: "slider.horizontal.3", tab: 2)
            sidebarItem("More", icon: "ellipsis", tab: 3)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(library.playlists) { playlist in
                        Button {
                            library.browsePlaylistID = playlist.id
                            library.browseSection = "Playlists"
                            selectedTab = 1
                        } label: {
                            Label(playlist.name, systemImage: "music.note")
                                .lineLimit(1).font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                        }.buttonStyle(.plain).musicHover()
                    }
                }
            }.padding(.top, 20)
            Spacer(minLength: 0)
            Button(action: { presentImporter(.track) }) {
                Label("Add Music", systemImage: "plus").padding(12)
            }.buttonStyle(.plain).musicHover()
        }
        .padding(.horizontal, 18)
        .frame(width: 220)
        .background(Color(white: 0.98))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.black.opacity(0.06)).frame(width: 1) }
    }

    private func sidebarItem(_ title: String, icon: String, tab: Int, section: String? = nil) -> some View {
        let active = selectedTab == tab && (section == nil || library.browseSection == section)
        return Button {
            if let section { library.browseSection = section }
            selectedTab = tab
        } label: {
            Label(title, systemImage: icon).font(.subheadline.weight(active ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .foregroundStyle(active ? themeManager.current.accent : themeManager.current.ink)
                .background(active ? themeManager.current.accent.opacity(0.07) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).musicHover()
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
            playlists: library.playlists,
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
            library.importPlaylists(backup.playlists)
            presetManager.importUserPresets(from: try JSONEncoder().encode(backup.userPresets))
            audioManager.applyEffects(backup.currentEffects)
        } catch {
            print("Ошибка импорта backup: \(error)")
        }
    }
}

@MainActor
private final class AudioEngineOwner: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let manager = AudioEngineManager()
}

private extension View {
    func miniPlayerInset(
        audioManager: AudioEngineManager,
        library: LibraryManager,
        presetManager: PresetManager
    ) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerBar(
                audioManager: audioManager,
                library: library,
                presetManager: presetManager
            )
            .background(Color.black.opacity(0.001))
        }
    }
}

#Preview {
    ContentView()
}
