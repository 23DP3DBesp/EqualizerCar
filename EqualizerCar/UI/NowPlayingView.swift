import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presetManager: PresetManager
    @Environment(\.carAmbientTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @GestureState private var dragOffset: CGFloat = 0
    @State private var showQuickPresetPicker = false

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 390

            ZStack {
                background

                ScrollView {
                    VStack(spacing: isCompact ? 18 : 24) {
                        header
                        artwork(size: min(geometry.size.width - 56, 360))
                        trackInfo
                        progressBlock
                        transportControls
                        actionButtons
                        smartModes
                    }
                    .padding(.horizontal, isCompact ? 20 : 28)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .offset(y: max(dragOffset, 0))
                }
            }
        }
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height > 0 { state = value.translation.height }
                }
                .onEnded { value in
                    if value.translation.height > 90 { dismiss() }
                }
        )
        .sheet(isPresented: $showQuickPresetPicker) {
            quickPresetPicker
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.white, Color.white],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.ink)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(audioManager.isPlaying ? "PLAYING FROM LIBRARY" : "READY")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(theme.mutedInk)
                Text("EqualizerCar")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.ink)
            }

            Spacer()

            Menu {
                if let currentTrack {
                    Button { library.addToQueue(currentTrack) } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
                    }
                    Button { library.toggleFavorite(currentTrack) } label: {
                        Label(currentTrack.isFavorite ? "Remove Favorite" : "Favorite", systemImage: "heart")
                    }
                }
                Button { audioManager.safeLoudModeEnabled.toggle() } label: {
                    Label("Headroom Guard", systemImage: "shield")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.ink)
                    .frame(width: 42, height: 42)
            }
        }
    }

    private func artwork(size: CGFloat) -> some View {
        TrackArtwork(track: currentTrack, size: size)
            .overlay(alignment: .bottom) {
                SpectrumAnalyzerView(levels: audioManager.spectrumLevels)
                    .frame(height: 36).padding(16).opacity(0.35)
            }
    }

    private var trackInfo: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(audioManager.currentTrackTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(currentTrack?.artistDisplayName ?? "Choose a song")
                    .font(.subheadline)
                    .foregroundStyle(theme.mutedInk)
            }

            Spacer()

            Button {
                if let currentTrack { library.toggleFavorite(currentTrack) }
            } label: {
                Image(systemName: currentTrack?.isFavorite == true ? "heart.fill" : "heart")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(currentTrack?.isFavorite == true ? theme.accent : theme.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(currentTrack == nil)
        }
    }

    private var progressBlock: some View {
        VStack(spacing: 8) {
            Slider(value: Binding(
                get: { progress },
                set: { audioManager.seek(to: Double($0) * audioManager.duration) }
            ))
            .tint(theme.accent)
            .disabled(audioManager.duration <= 0)

            HStack {
                Text(formatTime(audioManager.currentTime))
                Spacer()
                Text(formatTime(audioManager.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(theme.mutedInk)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 26) {
            Button { library.isShuffleEnabled.toggle() } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(library.isShuffleEnabled ? theme.accent : theme.ink)
                    .frame(width: 42, height: 42)
            }

            Button { audioManager.previousTrackRequested?() } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .frame(width: 48, height: 48)
            }

            Button { audioManager.togglePlayPause() } label: {
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 78)
                    .background(Circle().fill(theme.accent))
            }
            .disabled(audioManager.duration <= 0)

            Button { audioManager.nextTrackRequested?() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .frame(width: 48, height: 48)
            }

            Button { cycleRepeatMode() } label: {
                Image(systemName: repeatIcon)
                    .foregroundStyle(library.repeatMode == .off ? theme.ink : theme.accent)
                    .frame(width: 42, height: 42)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.ink)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            pillButton("Queue", icon: "text.badge.plus") {
                if let currentTrack { library.addToQueue(currentTrack) }
            }
            .disabled(currentTrack == nil)

            if let currentTrack {
                ShareLink(item: currentTrack.fileURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.black.opacity(0.04))
                        .clipShape(Capsule())
                }
            } else {
                pillButton("Share", icon: "square.and.arrow.up") {}
                    .disabled(true)
            }

            pillButton(audioManager.safeLoudModeEnabled ? "Guard On" : "Guard", icon: "shield.fill") {
                audioManager.safeLoudModeEnabled.toggle()
            }
        }
    }

    private var smartModes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loud bass chain")
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SmartLoudBassMode.allCases) { mode in
                        Button {
                            audioManager.applySmartLoudBassMode(mode)
                        } label: {
                            Text(mode.rawValue)
                                .font(.caption.weight(.black))
                                .foregroundStyle(audioManager.smartLoudBassMode == mode ? .black : theme.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .background(audioManager.smartLoudBassMode == mode ? theme.accent : Color.black.opacity(0.04))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pillButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.black.opacity(0.04))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var quickPresetPicker: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(presetManager.availableQuickPresetCandidates) { preset in
                        Button { presetManager.addQuickPreset(preset) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: preset.category.systemImage)
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(preset.category.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(theme.mutedInk)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(theme.accent)
                            }
                            .padding(12)
                            .background(theme.surface.opacity(0.96))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Add Quick Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showQuickPresetPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var currentTrack: Track? {
        guard let currentTrackID = audioManager.currentTrackID else { return nil }
        return library.tracks.first { $0.id == currentTrackID }
    }

    private var progress: Double {
        guard audioManager.duration > 0 else { return 0 }
        return min(max(audioManager.currentTime / audioManager.duration, 0), 1)
    }

    private var repeatIcon: String {
        switch library.repeatMode {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }

    private func cycleRepeatMode() {
        switch library.repeatMode {
        case .off: library.repeatMode = .all
        case .all: library.repeatMode = .one
        case .one: library.repeatMode = .off
        }
    }

    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "0:00" }
        let totalSeconds = max(Int(time), 0)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

#Preview {
    NowPlayingView(
        audioManager: AudioEngineManager(),
        library: LibraryManager(),
        presetManager: PresetManager()
    )
}
