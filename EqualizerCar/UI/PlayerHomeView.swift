import SwiftUI

struct PlayerHomeView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presetManager: PresetManager
    @Environment(\.carAmbientTheme) private var theme
    let addMusicAction: () -> Void
    var openLibraryAction: () -> Void = {}

    @State private var showQuickPresetPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                heroPlayer
                quickPicks
                recentlyPlayed
                quickActions
                dspModes
                queuePreview
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(theme.screenBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showQuickPresetPicker) {
            quickPresetPicker
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.accent)
                .frame(width: 34, height: 34)
                .overlay(
                    Text("E")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.ink)
                Text("\(library.tracks.count) tracks in your library")
                    .font(.caption)
                    .foregroundStyle(theme.mutedInk)
            }

            Spacer()

            Button(action: addMusicAction) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(theme.accent))
            }
            .buttonStyle(.plain)
        }
    }

    private var heroPlayer: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                albumArt(size: 118, iconSize: 42)

                VStack(alignment: .leading, spacing: 8) {
                    Text(audioManager.isPlaying ? "Now playing" : "Ready")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.accent)
                    Text(audioManager.currentTrackTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(audioManager.currentTrackID.flatMap { library.track(with: $0)?.artistDisplayName } ?? "Choose something you love")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.mutedInk)
                }

                Spacer(minLength: 0)
            }

        }

        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.white, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            actionChip("Shuffle", icon: "shuffle", isActive: library.isShuffleEnabled) {
                library.isShuffleEnabled.toggle()
            }
            actionChip("Bass Lab", icon: "speaker.wave.3.fill", isActive: audioManager.smartLoudBassMode != .clean) {
                audioManager.applySmartLoudBassMode(audioManager.smartLoudBassMode == .clean ? .loud : .clean)
            }
            actionChip("Safe", icon: "shield.fill", isActive: audioManager.safeLoudModeEnabled) {
                audioManager.safeLoudModeEnabled.toggle()
            }
        }
    }

    private var quickPicks: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Your music")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    collection("Favorites", subtitle: "\(library.favoriteTracks.count) songs", icon: "heart.fill", section: "Favorites", tracks: library.favoriteTracks, source: .favorites)
                    collection("Recently Played", subtitle: "\(library.recentlyPlayedTracks.count) songs", icon: "clock", section: "Recent", tracks: library.recentlyPlayedTracks, source: .recent)
                    collection("All Music", subtitle: "\(library.tracks.count) songs", icon: "music.note", section: "All", tracks: library.tracks, source: .library)
                }
            }
            sectionTitle("Playlists")
            if library.playlists.isEmpty {
                Button("Create your first playlist") { library.browseSection = "Playlists"; openLibraryAction() }
                    .font(.subheadline).padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(library.playlists) { playlist in
                            MusicCollectionCard(title: playlist.name, subtitle: "\(playlist.trackIDs.count) songs", icon: "music.note.list", artworkTrack: library.tracks(for: playlist.trackIDs).first) {
                                library.browsePlaylistID = playlist.id
                                library.browseSection = "Playlists"
                                openLibraryAction()
                            } play: {
                                playFirst(library.tracks(for: playlist.trackIDs), source: .playlist(playlist.id))
                            }
                        }
                    }
                }
            }
        }
    }

    private func collection(_ title: String, subtitle: String, icon: String, section: String, tracks: [Track], source: LibraryManager.PlaybackSource) -> some View {
        MusicCollectionCard(title: title, subtitle: subtitle, icon: icon) {
            library.browseSection = section
            openLibraryAction()
        } play: {
            playFirst(tracks, source: source)
        }
    }

    private var dspModes: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Loud bass modes")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SmartLoudBassMode.allCases) { mode in
                        Button {
                            audioManager.applySmartLoudBassMode(mode)
                        } label: {
                            Text(mode.rawValue)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(audioManager.smartLoudBassMode == mode ? .black : theme.ink)
                                .padding(.horizontal, 16)
                                .frame(height: 42)
                                .background(audioManager.smartLoudBassMode == mode ? theme.accent : Color.black.opacity(0.04))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recentlyPlayed: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Recently played")
            if library.recentlyPlayedTracks.isEmpty {
                emptyRow("Nothing played yet", icon: "clock")
            } else {
                VStack(spacing: 4) {
                    ForEach(library.recentlyPlayedTracks.prefix(5)) { track in
                        trackRow(track, source: .recent, tracks: library.recentlyPlayedTracks)
                    }
                }
            }
        }
    }

    private var queuePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Next in queue")
                Spacer()
                if !library.queueIDs.isEmpty {
                    Button("Clear") { library.clearQueue() }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.accent)
                }
            }
            if queueTracks.isEmpty {
                emptyRow("Queue is empty", icon: "text.line.first.and.arrowtriangle.forward")
            } else {
                VStack(spacing: 4) {
                    ForEach(queueTracks.prefix(4)) { track in
                        trackRow(track, source: .selection, tracks: queueTracks)
                    }
                }
            }
        }
    }

    private var quickPresetPicker: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(presetManager.availableQuickPresetCandidates) { preset in
                        Button {
                            presetManager.addQuickPreset(preset)
                        } label: {
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(theme.ink)
    }

    private func actionChip(_ title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(isActive ? .black : theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isActive ? theme.accent : Color.black.opacity(0.04))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func libraryTile(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    color.opacity(0.95)
                    Image(systemName: icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black.opacity(0.75))
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.mutedInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func trackRow(_ track: Track, source: LibraryManager.PlaybackSource, tracks: [Track]) -> some View {
        Button {
            library.selectPlaybackSource(source, tracks: tracks)
            library.play(track, audioManager: audioManager)
        } label: {
            HStack(spacing: 12) {
                TrackArtwork(track: track, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(audioManager.currentTrackID == track.id ? theme.accent : theme.ink)
                        .lineLimit(1)
                    Text(track.artistDisplayName + " · " + formatDuration(track.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.mutedInk)
                }
                Spacer()
                if audioManager.currentTrackID == track.id {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func emptyRow(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(theme.mutedInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func albumArt(size: CGFloat, iconSize: CGFloat) -> some View {
        TrackArtwork(track: audioManager.currentTrackID.flatMap { library.track(with: $0) }, size: size)
    }

    private func playFirst(_ tracks: [Track], source: LibraryManager.PlaybackSource = .selection) {
        library.selectPlaybackSource(source, tracks: tracks)
        guard let track = tracks.first else { return }
        library.play(track, audioManager: audioManager)
    }

    private var queueTracks: [Track] {
        library.tracks(for: library.queueIDs)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var progressText: String {
        "\(formatDuration(audioManager.currentTime)) / \(formatDuration(audioManager.duration))"
    }

    private func formatDuration(_ duration: Double) -> String {
        guard duration.isFinite, duration > 0 else { return "0:00" }
        let seconds = Int(duration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    PlayerHomeView(
        audioManager: AudioEngineManager(),
        library: LibraryManager(),
        presetManager: PresetManager(),
        addMusicAction: {}
    )
}
