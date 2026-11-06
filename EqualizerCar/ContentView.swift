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
    @State private var selectedTab: Int = {
#if DEBUG
        let requested = UserDefaults.standard.integer(forKey: "studio.previewTab")
        return (0...4).contains(requested) ? requested : 0
#else
        return 0
#endif
    }()

    @State private var activeImporter: ActiveImporter?
    @State private var isImporterPresented = false
    @State private var showPresetExporter = false
    @State private var showBackupExporter = false
    @State private var presetExportDocument = PresetExportDocument()
    @State private var backupExportDocument = AppBackupDocument()
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var importReviewItems: [LibraryManager.ImportCandidate] = []
    @State private var showImportReview = false

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
                    openLibraryAction: { selectedTab = 1 },
                    openPlayerAction: { selectedTab = 4 }
                )
            }
            .tabItem {
                Label("Home", systemImage: "house")
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
            .tabItem {
                Label("Library", systemImage: "music.note.list")
            }
            .tag(1)

            NavigationStack {
                NowPlayingView(audioManager: audioManager, library: library, presetManager: presetManager, embedded: true)
            }
            .tabItem { Label("Player", systemImage: "play.circle") }
            .tag(4)

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EqualizerTabView(audioManager: audioManager, presetManager: presetManager, isEmbedded: true)
                        EffectsPanelView(audioManager: audioManager)
                    }
                    .padding(20)
                }
                .background(themeManager.current.screenBackground.ignoresSafeArea())
                .navigationTitle("Equalizer")
            }
            .tabItem {
                Label("Equalizer", systemImage: "slider.vertical.3")
            }
            .tag(2)

            NavigationStack {
                StudioSettingsView(audio: audioManager, library: library, presets: presetManager,
                    showSavePreset: $showSavePresetAlert,
                    importPresets: { presentImporter(.preset) }, exportPresets: exportPresets,
                    importBackup: { presentImporter(.backup) }, exportBackup: exportBackup)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(3)
        }
            .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if selectedTab != 4, audioManager.currentTrackID != nil {
                    MiniPlayerBar(audioManager: audioManager, library: library, presetManager: presetManager, openPlayer: { selectedTab = 4 })
                }
                if sizeClass != .regular { StudioBottomNavigation(selection: $selectedTab) }
            }.background(themeManager.current.background)
        }
        .disabled(library.isLoadingLibrary)
        .overlay {
            if library.isLoadingLibrary {
                ProgressView("Loading library…").padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .carAmbientTheme(themeManager)
        .environment(\.locale, Locale(identifier: "ru"))
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
                    importReviewItems = library.inspectImportFiles(urls)
                    showImportReview = true
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
        .modifier(PlaybackErrorPresenter(audioManager: audioManager))
        .sheet(isPresented: $showImportReview, onDismiss: {
            if !importReviewItems.isEmpty { library.cancelImportReview() }
            importReviewItems = []
        }) {
            ImportReviewView(items: $importReviewItems, onCancel: {
                showImportReview = false
            }, onImport: {
                library.importSelectedFiles(importReviewItems)
                importReviewItems = []
                showImportReview = false
            })
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
            sidebarItem("Player", icon: "play.circle", tab: 4)
            sidebarItem("Equalizer", icon: "slider.horizontal.3", tab: 2)
            sidebarItem("Settings", icon: "gearshape", tab: 3)
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
        .background(themeManager.current.surface)
        .overlay(alignment: .trailing) { Rectangle().fill(themeManager.current.separator).frame(width: 1) }
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

private struct ImportReviewView: View {
    @Binding var items: [LibraryManager.ImportCandidate]
    let onCancel: () -> Void
    let onImport: () -> Void
    private var selectedCount: Int { items.filter(\.isSelected).count }
    private var totalBytes: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }

    var body: some View {
        NavigationStack {
            List {
                Section("Сводка") {
                    LabeledContent("Выбрано", value: "\(selectedCount) из \(items.count)")
                    LabeledContent("Размер", value: ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                }
                Section("Файлы") {
                    ForEach(items.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            Button {
                                items[index].isSelected.toggle()
                            } label: {
                                Image(systemName: items[index].isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .disabled(!items[index].readable || items[index].duplicate)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(items[index].url.lastPathComponent).lineLimit(1)
                                Text("\(items[index].status) · \(ByteCountFormatter.string(fromByteCount: items[index].size, countStyle: .file))")
                                    .font(.caption).foregroundStyle(items[index].duplicate || !items[index].readable ? .orange : .secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .navigationTitle("Импорт музыки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Импортировать (\(selectedCount))", action: onImport).disabled(selectedCount == 0) }
            }
        }
        .presentationDetents([.medium, .large])
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

private struct PlaybackErrorPresenter: ViewModifier {
    @ObservedObject var audioManager: AudioEngineManager

    func body(content: Content) -> some View {
        content.alert("Не удалось воспроизвести", isPresented: Binding(
            get: { audioManager.playbackError != nil },
            set: { if !$0 { audioManager.playbackError = nil } }
        )) {
            Button("OK", role: .cancel) { audioManager.playbackError = nil }
        } message: {
            Text(audioManager.playbackError ?? "")
        }
    }
}
