import SwiftUI

struct LegacyCarToolsView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presetManager: PresetManager
    @Environment(\.carAmbientTheme) private var theme
    @State private var showNoLookControls = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                noLookLauncher
                profileSection
                FMFrequencyHelperView()
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(theme.screenBackground.ignoresSafeArea())
        .navigationTitle("Legacy Car")
        .fullScreenCover(isPresented: $showNoLookControls) {
            NoLookGestureControlView(
                audioManager: audioManager,
                library: library,
                presetManager: presetManager
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Legacy Car Toolkit")
                .font(.title.weight(.bold))
                .foregroundStyle(theme.ink)
            Text("AUX, FM transmitter, and W211-focused signal tools.")
                .font(.caption)
                .foregroundStyle(theme.mutedInk)
        }
    }

    private var noLookLauncher: some View {
        Button {
            showNoLookControls = true
        } label: {
            Label("Open No-Look Touch Pad", systemImage: "hand.tap.fill")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.accent)
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("W211 & Legacy Profiles", systemImage: "car.fill")
                .font(.headline)
                .foregroundStyle(theme.ink)

            ForEach(LegacyCarAudioProfile.all) { profile in
                Button {
                    audioManager.applyLegacyCarProfile(profile)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(theme.secondaryAccent)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(theme.ink)
                                .lineLimit(2)
                            Text(profile.description)
                                .font(.caption)
                                .foregroundStyle(theme.mutedInk)
                                .lineLimit(3)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .liquidGlassPanel(cornerRadius: 12, tint: theme.surface.opacity(theme.glassOpacity))
    }
}

#Preview {
    LegacyCarToolsView(
        audioManager: AudioEngineManager(),
        library: LibraryManager(),
        presetManager: PresetManager()
    )
    .preferredColorScheme(.light)
}
