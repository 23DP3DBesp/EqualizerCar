import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presetManager: PresetManager
    var embedded = false
    @Environment(\.carAmbientTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var showQueue = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    TrackArtwork(track: currentTrack, size: min(geometry.size.width * 0.72, 340))
                        .shadow(color: theme.ink.opacity(theme.isDark ? 0.08 : 0.03), radius: 28, y: 12)
                        .padding(.top, 4)
                    trackInfo
                    StudioWaveformSeek(audio: audioManager)
                    StudioPlayerControls(audio: audioManager, library: library)
                    HStack(spacing: 16) {
                        Image(systemName: "speaker.fill")
                        Slider(value: $audioManager.outputGain, in: 0...1.25).accessibilityLabel("Volume")
                        Image(systemName: "speaker.wave.3")
                    }.font(.caption).foregroundStyle(theme.mutedInk)
                    quickControls
                    StudioPresetSelector(audio: audioManager, presets: presetManager)
                    bassModes
                }
                .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 32)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(theme.background.ignoresSafeArea())
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showQueue) { queueSheet }
    }

    private var header: some View {
        HStack {
            if !embedded {
                Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }
                    .accessibilityLabel("Close player")
            } else { Color.clear.frame(width: 44, height: 44) }
            Spacer()
            Text("Now Playing").font(.subheadline.weight(.semibold))
            Spacer()
            Button { showQueue = true } label: { Image(systemName: "text.line.first.and.arrowtriangle.forward").frame(width: 44, height: 44) }
                .accessibilityLabel("Playback queue")
        }.foregroundStyle(theme.ink).buttonStyle(StudioPressStyle())
    }

    private var trackInfo: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { if let currentTrack { library.toggleFavorite(currentTrack) } } label: {
                Image(systemName: currentTrack?.isFavorite == true ? "heart.fill" : "heart")
                    .font(.title3).contentTransition(.symbolEffect(.replace)).frame(width: 44, height: 44)
            }.disabled(currentTrack == nil).accessibilityLabel("Favorite")
            VStack(spacing: 8) {
                Text(currentTrack?.title ?? "Your next favorite")
                    .font(.system(size: 26, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
                Text(currentTrack?.artistDisplayName ?? "Choose a track from your library")
                    .font(.subheadline).foregroundStyle(theme.mutedInk).lineLimit(2).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity)
            Menu {
                if let currentTrack {
                    Button { library.addToQueue(currentTrack) } label: { Label("Add to queue", systemImage: "text.badge.plus") }
                    Menu("Add to playlist") {
                        ForEach(library.playlists) { playlist in
                            Button(playlist.name) { library.addToPlaylist(currentTrack, playlist: playlist) }
                        }
                    }
                    ShareLink(item: currentTrack.fileURL) { Label("Share track", systemImage: "square.and.arrow.up") }
                }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                .disabled(currentTrack == nil).accessibilityLabel("Track actions")
        }.foregroundStyle(theme.ink).buttonStyle(StudioPressStyle())
    }

    private var quickControls: some View {
        HStack(spacing: 12) {
            Button { showQueue = true } label: {
                Label("Queue", systemImage: "text.line.first.and.arrowtriangle.forward").frame(maxWidth: .infinity)
            }
            Button { audioManager.safeLoudModeEnabled.toggle() } label: {
                Label(audioManager.safeLoudModeEnabled ? "Guard on" : "Guard", systemImage: "shield")
                    .frame(maxWidth: .infinity)
            }
        }.font(.caption.weight(.medium)).foregroundStyle(theme.ink)
            .padding(.vertical, 16).background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .buttonStyle(StudioPressStyle())
    }

    private var bassModes: some View {
        VStack(alignment: .leading, spacing: 12) {
            StudioSectionHeader(title: "Listening mode", subtitle: "Your existing car DSP profiles")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SmartLoudBassMode.allCases) { mode in
                        Button { audioManager.applySmartLoudBassMode(mode) } label: {
                            Text(mode.localizedTitle).font(.caption.weight(.medium)).padding(.horizontal, 16).frame(height: 44)
                                .background(audioManager.smartLoudBassMode == mode ? theme.accent : theme.surface, in: Capsule())
                                .foregroundStyle(audioManager.smartLoudBassMode == mode ? theme.onAccent : theme.ink)
                        }.buttonStyle(StudioPressStyle())
                    }
                }
            }
        }
    }

    private var queueSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if library.playbackIDs.isEmpty && library.queueIDs.isEmpty {
                        ContentUnavailableView("Queue is empty", systemImage: "music.note.list", description: Text("Play a collection or add tracks to your queue."))
                    }
                    ForEach(library.tracks(for: library.queueIDs + library.playbackIDs.filter { !library.queueIDs.contains($0) })) { track in
                        Button { library.play(track, audioManager: audioManager) } label: {
                            HStack(spacing: 12) {
                                TrackArtwork(track: track, size: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title).font(.subheadline.weight(.medium)).lineLimit(1)
                                    Text(track.artistDisplayName).font(.caption).foregroundStyle(theme.mutedInk).lineLimit(1)
                                }
                                Spacer()
                                if audioManager.currentTrackID == track.id { Image(systemName: "waveform") }
                            }.padding(8).foregroundStyle(theme.ink)
                        }.buttonStyle(StudioPressStyle())
                    }
                }.padding(16)
            }.background(theme.background).navigationTitle("Up next")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Clear queued") { library.clearQueue() }.disabled(library.queueIDs.isEmpty) }
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { showQueue = false } }
                }
        }.presentationDetents([.medium, .large])
    }
    private var currentTrack: Track? { audioManager.currentTrackID.flatMap { library.track(with: $0) } }
}
