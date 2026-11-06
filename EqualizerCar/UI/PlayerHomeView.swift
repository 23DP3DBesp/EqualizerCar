import SwiftUI

struct PlayerHomeView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presetManager: PresetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.carAmbientTheme) private var theme
    let addMusicAction: () -> Void
    var openLibraryAction: () -> Void = {}
    var openPlayerAction: () -> Void = {}

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                header
                featured
                HStack(spacing: 12) {
                    shortcut("Избранное", detail: "Треков: \(library.favoriteTracks.count)", icon: "heart", section: "Избранное")
                    shortcut("Недавно прослушанные", detail: "Продолжите прослушивание", icon: "clock", section: "Recent")
                }
                if !library.recentlyPlayedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        StudioSectionHeader(title: "Back in rotation")
                        ForEach(library.recentlyPlayedTracks.prefix(4)) { track in
                            Button {
                                library.selectPlaybackSource(.recent, tracks: library.recentlyPlayedTracks)
                                library.play(track, audioManager: audioManager)
                            } label: {
                                HStack {
                                    StudioTrackIdentity(track: track, current: audioManager.currentTrackID == track.id)
                                    Image(systemName: "play.fill").font(.caption).foregroundStyle(theme.mutedInk).frame(width: 44, height: 44)
                                }
                            }.buttonStyle(StudioPressStyle())
                        }
                    }
                }
                playlists
                VStack(alignment: .leading, spacing: 16) {
                    StudioSectionHeader(title: "Your sound", subtitle: "Quick access to your saved DSP presets")
                    StudioPresetSelector(audio: audioManager, presets: presetManager)
                }
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 32)
            .frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.background(theme.background.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("EQUALIZERCAR").font(.system(size: 10, weight: .medium)).tracking(3).foregroundStyle(theme.mutedInk)
                Text(greeting).font(.system(size: 30, weight: .semibold)).foregroundStyle(theme.ink).lineLimit(1).minimumScaleFactor(0.75)
            }
            Spacer(minLength: 8)
            Menu {
                Picker("Appearance", selection: $themeManager.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in Label(appearance.title, systemImage: appearance.icon).tag(appearance) }
                }
            } label: {
                Image(systemName: theme.isDark ? "moon" : "sun.max").font(.system(size: 19)).foregroundStyle(theme.ink)
                    .frame(width: 48, height: 48).background(theme.surface, in: Circle())
            }.accessibilityLabel("Change appearance")
        }
    }
    private var featured: some View {
        Button(action: currentTrack == nil ? addMusicAction : openPlayerAction) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 20) {
                    TrackArtwork(track: currentTrack, size: 108)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentTrack == nil ? "MAKE IT YOURS" : "ON YOUR PLAYER")
                            .font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(theme.mutedInk)
                        Text(currentTrack?.title ?? "A space for\nyour music.")
                            .font(.system(size: 23, weight: .semibold)).foregroundStyle(theme.ink).lineLimit(3)
                        Text(currentTrack?.artistDisplayName ?? "Import your favorite tracks.")
                            .font(.caption).foregroundStyle(theme.mutedInk).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Text(currentTrack == nil ? "Add music" : "Open player").font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: currentTrack == nil ? "plus" : "arrow.up.right")
                }.foregroundStyle(theme.ink)
            }.padding(24).background(theme.surface, in: RoundedRectangle(cornerRadius: 28))
        }.buttonStyle(StudioPressStyle())
    }
    private func shortcut(_ title: String, detail: String, icon: String, section: String) -> some View {
        Button { library.browseSection = section; openLibraryAction() } label: {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon).font(.system(size: 24, weight: .light))
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(title)).font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                    Text(detail).font(.caption).foregroundStyle(theme.mutedInk).lineLimit(2)
                }
            }.foregroundStyle(theme.ink).frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                .padding(16).background(theme.surface, in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(StudioPressStyle())
    }
    private var playlists: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                StudioSectionHeader(title: "Made by you")
                Spacer()
                Button { library.browseSection = "Playlists"; openLibraryAction() } label: {
                    Image(systemName: "arrow.up.right").frame(width: 44, height: 44)
                }.foregroundStyle(theme.mutedInk).accessibilityLabel("Все плейлисты")
            }
            if library.playlists.isEmpty {
                Button { library.browseSection = "Playlists"; openLibraryAction() } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "plus").font(.title2).frame(width: 48, height: 48).background(theme.background, in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Ваш первый плейлист").font(.subheadline.weight(.medium))
                            Text("Музыка для каждой поездки.").font(.caption).foregroundStyle(theme.mutedInk)
                        }
                        Spacer(minLength: 0)
                    }.foregroundStyle(theme.ink).padding(16).background(theme.surface, in: RoundedRectangle(cornerRadius: 24))
                }.buttonStyle(StudioPressStyle())
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(library.playlists) { playlist in
                            MusicCollectionCard(title: playlist.name, subtitle: "Треков: \(playlist.trackIDs.count)", icon: "music.note.list", artworkTrack: library.tracks(for: playlist.trackIDs).first) {
                                library.browsePlaylistID = playlist.id; library.browseSection = "Playlists"; openLibraryAction()
                            } play: {
                                let tracks = library.tracks(for: playlist.trackIDs)
                                library.selectPlaybackSource(.playlist(playlist.id), tracks: tracks)
                                if let first = tracks.first { library.play(first, audioManager: audioManager) }
                            }
                        }
                    }
                }
            }
        }
    }
    private var currentTrack: Track? { audioManager.currentTrackID.flatMap { library.track(with: $0) } ?? library.recentlyPlayedTracks.first }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Доброе утро" : hour < 18 ? "Добрый день" : "Добрый вечер"
    }
}
