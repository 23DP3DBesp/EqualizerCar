import SwiftUI

struct StudioSettingsView: View {
    @ObservedObject var audio: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presets: PresetManager
    @EnvironmentObject private var themes: ThemeManager
    @Environment(\.carAmbientTheme) private var theme
    @Binding var showSavePreset: Bool
    let importPresets: () -> Void
    let exportPresets: () -> Void
    let importBackup: () -> Void
    let exportBackup: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                group("Appearance") {
                    Picker("Appearance", selection: $themes.appearance) {
                        ForEach(AppAppearance.allCases) { mode in Text(mode.title).tag(mode) }
                    }.pickerStyle(.segmented)
                    NavigationLink {
                        ScrollView { AmbientThemePickerView(themeManager: themes).padding(24) }
                            .background(theme.background).navigationTitle("Colors & style")
                    } label: { row("Colors & style", icon: "circle.lefthalf.filled") }
                }
                group("Audio") {
                    NavigationLink {
                        PresetsPanelView(audioManager: audio, presetManager: presets, showSavePresetAlert: $showSavePreset, importAction: importPresets, exportAction: exportPresets)
                    } label: { row("Presets", icon: "slider.horizontal.3") }
                    NavigationLink { BassLabView(audioManager: audio) } label: { row("Bass Lab", icon: "waveform") }
                }
                group("Playback") {
                    Toggle("Shuffle", isOn: $library.isShuffleEnabled)
                    Picker("Repeat", selection: $library.repeatMode) {
                        ForEach(LibraryManager.RepeatMode.allCases) { Text($0.localizedTitle).tag($0) }
                    }.tint(theme.ink)
                    Toggle("Save EQ per track", isOn: $library.perTrackPresetsEnabled)
                }
                group("Library & storage") {
                    NavigationLink {
                        SettingsPanelView(audioManager: audio, library: library, importBackupAction: importBackup, exportBackupAction: exportBackup)
                    } label: { row("Manage library", icon: "square.stack") }
                    HStack(spacing: 16) {
                        Button(action: importBackup) { Label("Restore", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity).frame(height: 44) }
                        Button(action: exportBackup) { Label("Backup", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).frame(height: 44) }
                    }.font(.subheadline).foregroundStyle(theme.ink)
                }
                group("On the road") {
                    NavigationLink { LegacyCarToolsView(audioManager: audio, library: library, presetManager: presets) } label: { row("Car tools", icon: "car") }
                }
#if DEBUG
                group("Developer") {
                    NavigationLink { DeveloperToolsView(audio: audio, library: library) } label: { row("Diagnostics & tools", icon: "wrench.and.screwdriver") }
                }
#endif
                VStack(alignment: .leading, spacing: 8) {
                    Text("EqualizerCar").font(.subheadline.weight(.medium))
                    Text("Your music. Your sound.").font(.caption)
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                        .font(.caption2)
                }.foregroundStyle(theme.mutedInk).padding(.horizontal, 8).padding(.bottom, 16)
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.background(theme.background.ignoresSafeArea()).navigationTitle("Settings")
            .foregroundStyle(theme.ink).buttonStyle(StudioPressStyle())
    }
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioSectionHeader(title: title)
            content()
        }.padding(20).background(theme.surface, in: RoundedRectangle(cornerRadius: 24))
    }
    private func row(_ title: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 19)).frame(width: 24).foregroundStyle(theme.mutedInk)
            Text(LocalizedStringKey(title)).font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.mutedInk)
        }.frame(minHeight: 44).contentShape(Rectangle())
    }
}
