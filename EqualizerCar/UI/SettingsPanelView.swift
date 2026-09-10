import SwiftUI

struct SettingsPanelView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.carAmbientTheme) private var theme
    let importBackupAction: () -> Void
    let exportBackupAction: () -> Void

    @State private var showDeleteAllConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AmbientThemePickerView(themeManager: themeManager)
                librarySettings
                playbackSettings
                backupSettings
                maintenanceSettings
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(theme.screenBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .confirmationDialog(
            "Delete all tracks?",
            isPresented: $showDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Tracks", role: .destructive) {
                audioManager.pause()
                library.deleteAllTracks()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes every imported audio file from the app library and clears playlists. Presets are kept.")
        }
    }

    private var librarySettings: some View {
        settingsCard(title: "Library", icon: "music.note.list") {
            Picker("Default Sort", selection: $library.sortOption) {
                ForEach(LibraryManager.SortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            Toggle(isOn: $library.perTrackPresetsEnabled) {
                Label("Auto-save EQ per track", systemImage: "music.note.house.fill")
            }
        }
    }

    private var playbackSettings: some View {
        settingsCard(title: "Playback", icon: "play.circle") {
            Toggle(isOn: $library.isShuffleEnabled) {
                Label("Shuffle", systemImage: "shuffle")
            }

            Picker("Repeat", selection: $library.repeatMode) {
                ForEach(LibraryManager.RepeatMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
        }
    }

    private var backupSettings: some View {
        settingsCard(title: "Backup", icon: "externaldrive") {
            HStack(spacing: 12) {
                Button(action: importBackupAction) {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: exportBackupAction) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var maintenanceSettings: some View {
        settingsCard(title: "Maintenance", icon: "wrench.and.screwdriver") {
            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                Label("Delete All Tracks", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(library.tracks.isEmpty)

            Text("Presets and app settings are kept.")
                .font(.caption)
                .foregroundStyle(theme.mutedInk)
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(theme.ink)
            content()
        }
        .padding(14)
        .themedPanel(cornerRadius: 12)
    }
}

#Preview {
    SettingsPanelView(
        audioManager: AudioEngineManager(),
        library: LibraryManager(),
        importBackupAction: {},
        exportBackupAction: {}
    )
}
