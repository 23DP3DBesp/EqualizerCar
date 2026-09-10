import SwiftUI

struct LibraryPanelView: View {
    private enum LibrarySection: String, CaseIterable, Identifiable {
        case all = "All"
        case favorites = "Favorites"
        case recent = "Recent"
        case queue = "Queue"
        case playlists = "Playlists"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "music.note.list"
            case .favorites: return "heart.fill"
            case .recent: return "clock.fill"
            case .queue: return "text.line.first.and.arrowtriangle.forward"
            case .playlists: return "rectangle.stack.fill"
            }
        }
    }

    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @Environment(\.carAmbientTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var showFilePicker: Bool

    private var selectedSection: LibrarySection {
        get { LibrarySection(rawValue: library.browseSection) ?? .all }
        nonmutating set { library.browseSection = newValue.rawValue }
    }
    private var selectedPlaylistID: UUID? {
        get { library.browsePlaylistID }
        nonmutating set { library.browsePlaylistID = newValue }
    }
    @State private var renamingTrack: Track?
    @State private var renameTitle = ""
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var renamingPlaylist: AudioPlaylist?
    @State private var playlistRenameName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                filters
                if library.isImporting { importingRow }
                if let importErrorMessage = library.importErrorMessage { errorRow(importErrorMessage) }
                playlistShelf
                searchAndSort
                if selectedSection == .playlists { playlistControls }
                content
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(theme.screenBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { updatePlaybackScope() }
        .onChange(of: selectedSection) { _, _ in updatePlaybackScope() }
        .onChange(of: selectedPlaylistID) { _, _ in updatePlaybackScope() }
        .onChange(of: library.searchText) { _, _ in updatePlaybackScope() }
        .onChange(of: library.sortOption) { _, _ in updatePlaybackScope() }
        .alert("Rename Track", isPresented: renameAlertBinding) {
            TextField("Track title", text: $renameTitle)
            Button("Cancel", role: .cancel) {
                renamingTrack = nil
                renameTitle = ""
            }
            Button("Save") {
                if let renamingTrack {
                    library.renameTrack(renamingTrack, title: renameTitle)
                }
                renamingTrack = nil
                renameTitle = ""
            }
        }
        .alert("New Playlist", isPresented: $showNewPlaylistAlert) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
            Button("Create") {
                library.createPlaylist(named: newPlaylistName)
                selectedPlaylistID = library.playlists.last?.id
                selectedSection = .playlists
                newPlaylistName = ""
            }
        }
        .alert("Rename Playlist", isPresented: playlistRenameAlertBinding) {
            TextField("Playlist name", text: $playlistRenameName)
            Button("Cancel", role: .cancel) {
                renamingPlaylist = nil
                playlistRenameName = ""
            }
            Button("Save") {
                if let renamingPlaylist {
                    library.renamePlaylist(renamingPlaylist, name: playlistRenameName)
                }
                renamingPlaylist = nil
                playlistRenameName = ""
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.black.opacity(0.04))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(theme.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Your Library")
                    .font(.title.weight(.bold))
                    .foregroundStyle(theme.ink)
                Text("\(library.tracks.count) songs • \(library.playlists.count) playlists")
                    .font(.caption)
                    .foregroundStyle(theme.mutedInk)
            }

            Spacer()

            Button { showFilePicker = true } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.ink)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Label(section.rawValue, systemImage: section.icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selectedSection == section ? theme.accent : theme.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(selectedSection == section ? theme.accent.opacity(0.08) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var playlistShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Playlists and shortcuts")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button { showNewPlaylistAlert = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    playlistCard(title: "Liked Songs", subtitle: "\(library.favoriteTracks.count) songs", icon: "heart.fill", color: .pink) {
                        selectedSection = .favorites
                    }
                    playlistCard(title: "Recently Played", subtitle: "\(library.recentlyPlayedTracks.count) songs", icon: "clock.fill", color: theme.accent) {
                        selectedSection = .recent
                    }
                    playlistCard(title: "Queue", subtitle: "\(library.queueIDs.count) songs", icon: "text.line.first.and.arrowtriangle.forward", color: .cyan) {
                        selectedSection = .queue
                    }
                    ForEach(library.playlists) { playlist in
                        playlistCard(title: playlist.name, subtitle: "\(playlist.trackIDs.count) songs", icon: "music.note.list", color: playlistColor(for: playlist), artworkTrack: library.tracks(for: playlist.trackIDs).first) {
                            selectedPlaylistID = playlist.id
                            selectedSection = .playlists
                        }
                    }
                    Button { showNewPlaylistAlert = true } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(width: 54, height: 54)
                                .background(theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text("New Playlist")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.ink)
                                .lineLimit(2)
                            Text("Create mix")
                                .font(.caption2)
                                .foregroundStyle(theme.mutedInk)
                        }
                        .frame(width: 130, height: 154, alignment: .topLeading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var searchAndSort: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.mutedInk)
                TextField("Search in your library", text: $library.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(theme.ink)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Picker("Sort", selection: $library.sortOption) {
                    ForEach(LibraryManager.SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(theme.ink)

                Spacer()

                Toggle(isOn: $library.isShuffleEnabled) {
                    Label("Shuffle", systemImage: "shuffle")
                }
                .toggleStyle(.button)
                .font(.caption.weight(.bold))
                .tint(theme.accent)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.mutedInk)
        }
    }

    private var playlistControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Picker("Playlist", selection: selectedPlaylistBinding) {
                    Text("Choose Playlist").tag(UUID?.none)
                    ForEach(library.playlists) { playlist in
                        Text(playlist.name).tag(Optional(playlist.id))
                    }
                }
                .pickerStyle(.menu)
                .disabled(library.playlists.isEmpty)

                Spacer()

                Button { showNewPlaylistAlert = true } label: {
                    Label("New", systemImage: "plus.circle")
                }
                .font(.caption.weight(.bold))
            }

            if let selectedPlaylist {
                HStack(spacing: 14) {
                    Text("\(selectedPlaylist.trackIDs.count) songs")
                        .font(.caption)
                        .foregroundStyle(theme.mutedInk)
                    Spacer()
                    Button { renamingPlaylist = selectedPlaylist; playlistRenameName = selectedPlaylist.name } label: {
                        Image(systemName: "pencil")
                    }
                    Button(role: .destructive) {
                        library.deletePlaylist(selectedPlaylist)
                        selectedPlaylistID = library.playlists.first?.id
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .font(.caption.weight(.bold))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(sectionHeading)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text("\(currentVisibleTracks.count)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(theme.mutedInk)
            }

            if library.tracks.isEmpty && selectedSection != .playlists {
                emptyState("Add your first track", icon: "music.note.list", actionTitle: "Add Music", action: { showFilePicker = true })
            } else if currentVisibleTracks.isEmpty {
                emptyState(emptyTitle, icon: emptyIcon, actionTitle: selectedSection == .playlists ? "New Playlist" : nil) {
                    showNewPlaylistAlert = true
                }
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(Array(currentVisibleTracks.enumerated()), id: \.element.id) { index, track in
                        trackRow(track, number: index + 1)
                    }
                }
            }
        }
    }

    private var importingRow: some View {
        HStack(spacing: 10) {
            ProgressView().tint(theme.accent)
            Text("Importing track...")
                .font(.subheadline)
                .foregroundStyle(theme.mutedInk)
        }
        .padding(12)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func errorRow(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func playlistCard(title: String, subtitle: String, icon: String, color: Color, artworkTrack: Track? = nil, action: @escaping () -> Void) -> some View {
        MusicCollectionCard(title: title, subtitle: subtitle, icon: icon, artworkTrack: artworkTrack, open: action) {
            action()
            updatePlaybackScope()
            if let first = currentVisibleTracks.first { library.play(first, audioManager: audioManager) }
        }
    }

    private func trackRow(_ track: Track, number: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                updatePlaybackScope()
                library.play(track, audioManager: audioManager)
            } label: {
                HStack(spacing: 12) {
                    Text("\(number)")
                        .font(.caption.monospacedDigit()).foregroundStyle(theme.mutedInk).frame(width: 22)
                    TrackArtwork(track: track, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(audioManager.currentTrackID == track.id ? theme.accent : theme.ink)
                            .lineLimit(1)
                        if sizeClass != .regular {
                            Text(track.artistDisplayName).font(.caption).foregroundStyle(theme.mutedInk).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    if sizeClass == .regular {
                        Text(track.artistDisplayName).font(.subheadline).foregroundStyle(theme.mutedInk)
                            .lineLimit(1).frame(maxWidth: 180, alignment: .leading)
                    }
                    Text(formatDuration(track.duration)).font(.caption.monospacedDigit())
                        .foregroundStyle(theme.mutedInk).frame(width: 42, alignment: .trailing)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { library.toggleFavorite(track) } label: {
                Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(track.isFavorite ? theme.accent : theme.mutedInk)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Menu {
                Button { library.addToQueue(track) } label: {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                }
                if !library.playlists.isEmpty {
                    Menu {
                        ForEach(library.playlists) { playlist in
                            Button {
                                library.addToPlaylist(track, playlist: playlist)
                            } label: {
                                Label(playlist.name, systemImage: "plus")
                            }
                        }
                    } label: {
                        Label("Add to Playlist", systemImage: "music.note.list")
                    }
                }
                if selectedSection == .playlists, let selectedPlaylist {
                    Button(role: .destructive) {
                        library.removeFromPlaylist(track, playlist: selectedPlaylist)
                    } label: {
                        Label("Remove from Playlist", systemImage: "minus.circle")
                    }
                }
                Button { renamingTrack = track; renameTitle = track.title } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    if audioManager.currentTrackID == track.id { audioManager.pause() }
                    library.deleteTrack(track)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(theme.mutedInk)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.vertical, 7)
        .musicHover()
    }

    private func albumArt(track: Track, size: CGFloat) -> some View {
        ZStack {
            Color(white: 0.96)
            Image(systemName: audioManager.currentTrackID == track.id ? "speaker.wave.2.fill" : "music.note")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black.opacity(0.68))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func emptyState(_ title: String, icon: String, actionTitle: String?, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(theme.mutedInk)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.ink)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var currentVisibleTracks: [Track] {
        switch selectedSection {
        case .all:
            return library.filteredTracks
        case .favorites:
            return library.filteredTracks.filter(\.isFavorite)
        case .recent:
            let matchingIDs = Set(library.filteredTracks.map(\.id))
            return library.recentlyPlayedTracks.filter { matchingIDs.contains($0.id) }
        case .queue:
            return library.tracks(for: library.queueIDs.isEmpty ? library.playbackIDs : library.queueIDs)
        case .playlists:
            guard let selectedPlaylist else { return [] }
            let playlistIDs = Set(selectedPlaylist.trackIDs)
            return library.filteredTracks.filter { playlistIDs.contains($0.id) }
        }
    }

    private func updatePlaybackScope() {
        let source: LibraryManager.PlaybackSource
        switch selectedSection {
        case .all: source = .library
        case .favorites: source = .favorites
        case .recent: source = .recent
        case .queue: source = .selection
        case .playlists:
            source = selectedPlaylist.map { .playlist($0.id) } ?? .selection
        }
        // The manually queued list is copied before selecting it clears pending overrides.
        if selectedSection == .queue, library.queueIDs.isEmpty { return }
        library.selectPlaybackSource(source, tracks: currentVisibleTracks, query: selectedSection == .queue ? "" : library.searchText)
    }

    private var sectionHeading: String {
        switch selectedSection {
        case .all: return "Songs"
        case .favorites: return "Liked Songs"
        case .recent: return "Recently Played"
        case .queue: return "Queue"
        case .playlists: return selectedPlaylist?.name ?? "Playlists"
        }
    }

    private var emptyTitle: String {
        switch selectedSection {
        case .all: return "No matching songs"
        case .favorites: return "No liked songs yet"
        case .recent: return "Nothing played yet"
        case .queue: return "Queue is empty"
        case .playlists: return library.playlists.isEmpty ? "No playlists yet" : "Playlist is empty"
        }
    }

    private var emptyIcon: String {
        switch selectedSection {
        case .all: return "magnifyingglass"
        case .favorites: return "heart"
        case .recent: return "clock"
        case .queue: return "text.line.first.and.arrowtriangle.forward"
        case .playlists: return "rectangle.stack"
        }
    }

    private func trackSubtitle(_ track: Track) -> String {
        if selectedSection == .recent, let lastPlayedAt = track.lastPlayedAt {
            return "Played \(lastPlayedAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return track.artistDisplayName
    }

    private func formatDuration(_ duration: Double) -> String {
        guard duration.isFinite, duration > 0 else { return "0:00" }
        let totalSeconds = Int(duration)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var selectedPlaylist: AudioPlaylist? {
        guard let selectedPlaylistID else { return library.playlists.first }
        return library.playlists.first { $0.id == selectedPlaylistID } ?? library.playlists.first
    }

    private var selectedPlaylistBinding: Binding<UUID?> {
        Binding(get: { selectedPlaylist?.id }, set: { selectedPlaylistID = $0 })
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingTrack != nil },
            set: { isPresented in
                if !isPresented {
                    renamingTrack = nil
                    renameTitle = ""
                }
            }
        )
    }

    private var playlistRenameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingPlaylist != nil },
            set: { isPresented in
                if !isPresented {
                    renamingPlaylist = nil
                    playlistRenameName = ""
                }
            }
        )
    }

    private func playlistColor(for playlist: AudioPlaylist) -> Color {
        playlistColor(seed: playlist.name)
    }

    private func playlistColor(seed: String) -> Color {
        let colors: [Color] = [
            theme.accent,
            .pink,
            .cyan,
            theme.secondaryAccent,
            Color(red: 0.55, green: 0.38, blue: 0.92),
            Color(red: 0.95, green: 0.38, blue: 0.28)
        ]
        let index = abs(seed.hashValue) % colors.count
        return colors[index]
    }
}
