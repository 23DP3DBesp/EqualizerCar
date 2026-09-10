import SwiftUI

struct MiniPlayerBar: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presetManager: PresetManager
    @Environment(\.carAmbientTheme) private var theme
    @State private var showNowPlaying = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 28) {
                trackDetails.frame(width: 220)
                VStack(spacing: 2) {
                    transport
                    PlaybackProgressView(audioManager: audioManager)
                }.frame(minWidth: 250, maxWidth: 560)
                volume.frame(width: 150)
            }.padding(.horizontal, 24).padding(.vertical, 12)
            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    trackDetails
                    playButton
                    control("Next", icon: "forward.fill") { library.playNext(audioManager: audioManager) }
                }
                PlaybackProgressView(audioManager: audioManager)
                HStack {
                    control("Shuffle", icon: "shuffle", active: library.isShuffleEnabled) { library.isShuffleEnabled.toggle() }
                    control("Previous", icon: "backward.fill") { library.playPrevious(audioManager: audioManager) }
                    repeatButton
                    Spacer(minLength: 8)
                    volume.frame(maxWidth: 140)
                }
            }.padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(Color.white)
        .overlay(alignment: .top) { Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1) }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView(audioManager: audioManager, library: library, presetManager: presetManager)
        }
    }

    private var trackDetails: some View {
        HStack(spacing: 10) {
            Button { showNowPlaying = true } label: {
                HStack(spacing: 10) {
                    TrackArtwork(track: currentTrack, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(audioManager.currentTrackTitle).font(.subheadline.weight(.semibold)).foregroundStyle(theme.ink).lineLimit(1)
                        Text(currentTrack?.artistDisplayName ?? "Choose a song")
                            .font(.caption).foregroundStyle(theme.mutedInk).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.buttonStyle(.plain).accessibilityLabel("Open Now Playing")
            control("Favorite", icon: currentTrack?.isFavorite == true ? "heart.fill" : "heart", active: currentTrack?.isFavorite == true) {
                if let currentTrack { library.toggleFavorite(currentTrack) }
            }.disabled(currentTrack == nil)
        }
    }

    private var transport: some View {
        HStack(spacing: 16) {
            control("Shuffle", icon: "shuffle", active: library.isShuffleEnabled) { library.isShuffleEnabled.toggle() }
            control("Previous", icon: "backward.fill") { library.playPrevious(audioManager: audioManager) }
            playButton
            control("Next", icon: "forward.fill") { library.playNext(audioManager: audioManager) }
            repeatButton
        }
    }

    private var playButton: some View {
        Button {
            if audioManager.currentTrackID == nil, let first = library.tracks(for: library.playbackIDs).first {
                library.play(first, audioManager: audioManager)
            } else { audioManager.togglePlayPause() }
        } label: {
            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                .font(.headline).foregroundStyle(.white).frame(width: 42, height: 42)
                .background(theme.accent, in: Circle())
        }.buttonStyle(.plain).hoverEffect(.highlight)
        .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Play")
        .disabled(audioManager.currentTrackID == nil && library.playbackIDs.isEmpty)
    }

    private var repeatButton: some View {
        control("Repeat: \(library.repeatMode.rawValue)", icon: library.repeatMode == .one ? "repeat.1" : "repeat", active: library.repeatMode != .off) {
            switch library.repeatMode {
            case .off: library.repeatMode = .all
            case .all: library.repeatMode = .one
            case .one: library.repeatMode = .off
            }
        }
    }

    private var volume: some View {
        HStack(spacing: 6) {
            Image(systemName: audioManager.outputGain == 0 ? "speaker.slash" : "speaker.wave.2")
                .font(.caption).foregroundStyle(theme.mutedInk)
            Slider(value: $audioManager.outputGain, in: 0...1.25)
                .tint(theme.ink).accessibilityLabel("Volume")
        }
    }

    private func control(_ title: String, icon: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.subheadline)
                .foregroundStyle(active ? theme.accent : theme.ink).frame(width: 32, height: 36)
        }.buttonStyle(.plain).musicHover().accessibilityLabel(title)
    }

    private var currentTrack: Track? {
        audioManager.currentTrackID.flatMap { library.track(with: $0) }
    }
}

struct TrackArtwork: View {
    let track: Track?
    let size: CGFloat
    @State private var decodedImage: UIImage?
    var body: some View {
        Group {
            if let image = decodedImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color(white: 0.95).overlay {
                    Image(systemName: "music.note").font(.system(size: size * 0.36, weight: .light)).foregroundStyle(Color(white: 0.35))
                }
            }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
        .task(id: ArtworkRequest(id: track?.id, data: track?.artworkData)) {
            decodedImage = nil
            guard let track, let data = track.artworkData else { return }
            let image = await ArtworkImageCache.shared.image(id: track.id, data: data)
            guard !Task.isCancelled else { return }
            decodedImage = image
        }
    }
}

private struct ArtworkRequest: Equatable {
    let id: UUID?
    let data: Data?
}

/// Bounded decoded image cache, shared by the library, cards and the bottom player.
private actor ArtworkImageCache {
    static let shared = ArtworkImageCache()
    private let cache = NSCache<NSUUID, Entry>()
    private final class Entry {
        let data: Data
        let image: UIImage
        init(data: Data, image: UIImage) { self.data = data; self.image = image }
    }

    init() { cache.totalCostLimit = 24 * 1024 * 1024 }

    func image(id: UUID, data: Data) -> UIImage? {
        let key = id as NSUUID
        if let entry = cache.object(forKey: key), entry.data == data { return entry.image }
        guard let source = UIImage(data: data) else { return nil }
        let image = source.preparingForDisplay() ?? source
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? data.count
        cache.setObject(Entry(data: data, image: image), forKey: key, cost: cost)
        return image
    }
}
