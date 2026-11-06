import SwiftUI

struct LibraryPanelView: View {
    private enum LibrarySection: String, CaseIterable, Identifiable {
        case all = "All"
        case artists = "Artists"
        case albums = "Albums"
        case favorites = "Favorites"
        case recent = "Recent"
        case queue = "Очередь"
        case playlists = "Playlists"

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .all: return "Все треки"
            case .artists: return "Исполнители"
            case .albums: return "Альбомы"
            case .favorites: return "Избранное"
            case .recent: return "Недавние"
            case .queue: return "Очередь"
            case .playlists: return "Плейлисты"
            }
        }

        var icon: String {
            switch self {
            case .all: return "music.note.list"
            case .artists: return "person.2"
            case .albums: return "square.stack"
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
    @State private var selectedArtist: String?
    @State private var selectedAlbum: String?
    @State private var renamingTrack: Track?
    @State private var renameTitle = ""
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var renamingPlaylist: AudioPlaylist?
    @State private var playlistRenameName = ""
    @State private var isSelectionMode = false
    @State private var selectedTrackIDs = Set<UUID>()
    @State private var isScanningDuplicates = false
    @State private var duplicateCopiesSelected = 0
    @State private var showDeleteSelectionConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                filters
                if library.isImporting { importingRow }
                if let importErrorMessage = library.importErrorMessage { errorRow(importErrorMessage) }
                searchAndSort
                if selectedSection == .playlists || !library.searchText.isEmpty { playlistShelf }
                if selectedSection == .albums || !library.searchText.isEmpty { albumShelf }
                if selectedSection == .artists || !library.searchText.isEmpty { artistShelf }
                if selectedSection == .favorites || (selectedSection == .albums && selectedAlbum != nil) || (selectedSection == .playlists && selectedPlaylist != nil) { collectionHero }
                if selectedSection == .playlists { playlistControls }
                if (selectedSection != .artists || selectedArtist != nil) && (selectedSection != .albums || selectedAlbum != nil) { content }
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
        .onChange(of: selectedAlbum) { _, _ in updatePlaybackScope() }
        .onChange(of: selectedArtist) { _, _ in updatePlaybackScope() }
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
        .alert("Delete selected tracks?", isPresented: $showDeleteSelectionConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete \(selectedTrackIDs.count)", role: .destructive) { deleteSelectedTracks() }
        } message: {
            Text("The selected audio files will be removed from the library and its playlists.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.surface)
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(theme.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Медиатека")
                    .font(.title.weight(.bold))
                    .foregroundStyle(theme.ink)
                Text("Треков: \(library.tracks.count) • Плейлистов: \(library.playlists.count)")
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
                        Text(section == .all ? "Песни" : section.localizedTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selectedSection == section ? theme.onAccent : theme.mutedInk)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(selectedSection == section ? theme.accent : theme.surface)
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
                    playlistCard(title: "Понравившиеся", subtitle: "Треков: \(library.favoriteTracks.count)", icon: "heart.fill", color: .pink) {
                        selectedSection = .favorites
                    }
                    playlistCard(title: "Недавно прослушанные", subtitle: "Треков: \(library.recentlyPlayedTracks.count)", icon: "clock.fill", color: theme.accent) {
                        selectedSection = .recent
                    }
                    playlistCard(title: "Очередь", subtitle: "Треков: \(library.queueIDs.count)", icon: "text.line.first.and.arrowtriangle.forward", color: .cyan) {
                        selectedSection = .queue
                    }
                    ForEach(library.playlists.filter { library.searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(library.searchText) }) { playlist in
                        playlistCard(title: playlist.name, subtitle: "Треков: \(playlist.trackIDs.count)", icon: "music.note.list", color: playlistColor(for: playlist), artworkTrack: library.tracks(for: playlist.trackIDs).first) {
                            selectedPlaylistID = playlist.id
                            library.searchText = ""
                            selectedSection = .playlists
                        }
                    }
                    Button { showNewPlaylistAlert = true } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(theme.onAccent)
                                .frame(width: 54, height: 54)
                                .background(theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                TextField("Songs, artists, playlists", text: $library.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(theme.ink)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack {
                Picker("Sort", selection: $library.sortOption) {
                    ForEach(LibraryManager.SortOption.allCases) { option in
                        Text(option.localizedTitle).tag(option)
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
            HStack(spacing: 10) {
                Button(isSelectionMode ? "Done" : "Select") {
                    isSelectionMode.toggle()
                    if !isSelectionMode { selectedTrackIDs.removeAll(); duplicateCopiesSelected = 0 }
                }
                .buttonStyle(.bordered)
                Button {
                    selectedTrackIDs = Set(currentVisibleTracks.map(\.id))
                    duplicateCopiesSelected = 0
                    isSelectionMode = true
                } label: { Label("Select visible", systemImage: "checkmark.circle") }
                    .buttonStyle(.bordered)
                Button {
                    isScanningDuplicates = true
                    Task {
                        let groups = await library.findDuplicateTrackGroups()
                        let duplicateIDs = groups.flatMap { Array($0.dropFirst()).map(\.id) }
                        await MainActor.run {
                            library.searchText = ""
                            selectedSection = .all
                            selectedArtist = nil
                            selectedAlbum = nil
                            selectedTrackIDs = Set(duplicateIDs)
                            duplicateCopiesSelected = duplicateIDs.count
                            isSelectionMode = true
                            isScanningDuplicates = false
                        }
                    }
                } label: {
                    if isScanningDuplicates { ProgressView() }
                    else { Label("Find duplicates", systemImage: "doc.on.doc") }
                }
                .buttonStyle(.bordered)
                .disabled(isScanningDuplicates || library.tracks.count < 2)
                if !selectedTrackIDs.isEmpty {
                    Button(role: .destructive) { showDeleteSelectionConfirmation = true } label: {
                        Label("Delete (\(selectedTrackIDs.count))", systemImage: "trash")
                    }.buttonStyle(.bordered)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.mutedInk)
            if duplicateCopiesSelected > 0 {
                Text("Found \(duplicateCopiesSelected) duplicate copies by file hash. The oldest copy in each group is kept.")
                    .font(.caption).foregroundStyle(theme.mutedInk)
            }
        }
    }

    private var albumShelf: some View {
        VStack(alignment: .leading, spacing: 16) {
            StudioSectionHeader(title: "Albums")
            let albums = Array(Set(library.filteredTracks.compactMap(\.album).filter { !$0.isEmpty })).sorted()
            if albums.isEmpty { Text("Albums appear when your files contain album tags.").font(.caption).foregroundStyle(theme.mutedInk) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(albums, id: \.self) { album in
                        let tracks = library.tracks.filter { $0.album == album }
                        MusicCollectionCard(title: album, subtitle: "Треков: \(tracks.count)", icon: "square.stack", artworkTrack: tracks.first) {
                            library.searchText = ""; selectedAlbum = album; selectedSection = .albums
                        } play: {
                            library.searchText = ""; selectedAlbum = album; selectedSection = .albums
                            library.selectPlaybackSource(.selection, tracks: tracks)
                            if let first = tracks.first { library.play(first, audioManager: audioManager) }
                        }
                    }
                }
            }
        }
    }

    private var artistShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            StudioSectionHeader(title: "Artists")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(Set(library.filteredTracks.map(\.artistDisplayName))).sorted(), id: \.self) { artist in
                        Button { selectedArtist = artist; selectedSection = .artists } label: {
                            Label(artist, systemImage: "person.crop.circle")
                                .font(.subheadline).lineLimit(1).padding(16)
                                .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(theme.ink)
                        }.buttonStyle(StudioPressStyle())
                    }
                }
            }
        }
    }

    private var collectionHero: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 20) {
                TrackArtwork(track: currentVisibleTracks.first, size: 108)
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(selectedSection == .favorites ? "ИЗБРАННОЕ" : selectedSection == .albums ? "АЛЬБОМ" : "ПЛЕЙЛИСТ") · \(currentVisibleTracks.count) ТРЕКОВ")
                        .font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(theme.mutedInk)
                    Text(LocalizedStringKey(sectionHeading)).font(.system(size: 26, weight: .semibold)).foregroundStyle(theme.ink).lineLimit(3)
                    Text("Your personal soundtrack").font(.caption).foregroundStyle(theme.mutedInk)
                }
            }
            HStack(spacing: 12) {
                Button { playCollection(shuffled: false) } label: {
                    Label("Play", systemImage: "play.circle").frame(maxWidth: .infinity).frame(height: 48)
                        .background(theme.accent, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(theme.onAccent)
                }
                Button { playCollection(shuffled: true) } label: {
                    Label("Shuffle", systemImage: "shuffle").frame(maxWidth: .infinity).frame(height: 48)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(theme.ink)
                }
            }.font(.subheadline.weight(.medium)).buttonStyle(StudioPressStyle()).disabled(currentVisibleTracks.isEmpty)
        }.padding(.vertical, 8)
    }

    private func playCollection(shuffled: Bool) {
        library.isShuffleEnabled = shuffled
        updatePlaybackScope()
        let first = shuffled ? currentVisibleTracks.randomElement() : currentVisibleTracks.first
        if let first { library.play(first, audioManager: audioManager) }
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
                    Text("Треков: \(selectedPlaylist.trackIDs.count)")
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
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LocalizedStringKey(sectionHeading))
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
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func errorRow(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                if isSelectionMode {
                    if selectedTrackIDs.contains(track.id) { selectedTrackIDs.remove(track.id) }
                    else { selectedTrackIDs.insert(track.id) }
                } else {
                    updatePlaybackScope()
                    library.play(track, audioManager: audioManager)
                }
            } label: {
                HStack(spacing: 8) {
                    if isSelectionMode {
                        Image(systemName: selectedTrackIDs.contains(track.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedTrackIDs.contains(track.id) ? theme.accent : theme.mutedInk)
                    }
                    StudioTrackIdentity(track: track, number: number, current: audioManager.currentTrackID == track.id)
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
        .padding(.vertical, 8).padding(.horizontal, 8)
        .background(audioManager.currentTrackID == track.id ? theme.surface : .clear, in: RoundedRectangle(cornerRadius: 16))
        .musicHover()
    }

    private func deleteSelectedTracks() {
        let tracksToDelete = library.tracks.filter { selectedTrackIDs.contains($0.id) }
        if tracksToDelete.contains(where: { $0.id == audioManager.currentTrackID }) { audioManager.unloadCurrentTrack() }
        library.deleteTracks(tracksToDelete)
        selectedTrackIDs.removeAll()
        duplicateCopiesSelected = 0
        isSelectionMode = false
    }

    private func albumArt(track: Track, size: CGFloat) -> some View {
        ZStack {
            theme.surface
            Image(systemName: audioManager.currentTrackID == track.id ? "speaker.wave.2.fill" : "music.note")
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.mutedInk)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func emptyState(_ title: String, icon: String, actionTitle: String?, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(theme.mutedInk)
            Text(LocalizedStringKey(title))
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
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var currentVisibleTracks: [Track] {
        switch selectedSection {
        case .all:
            return library.filteredTracks
        case .artists:
            return library.filteredTracks.filter { $0.artistDisplayName == selectedArtist }
        case .albums:
            return library.filteredTracks.filter { $0.album == selectedAlbum }
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
        case .artists, .albums: source = .selection
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
        case .all: return "Песни"
        case .artists: return selectedArtist ?? "Исполнители"
        case .albums: return selectedAlbum ?? "Альбомы"
        case .favorites: return "Понравившиеся"
        case .recent: return "Недавно прослушанные"
        case .queue: return "Очередь"
        case .playlists: return selectedPlaylist?.name ?? "Плейлисты"
        }
    }

    private var emptyTitle: String {
        switch selectedSection {
        case .all: return "Подходящих треков не найдено"
        case .artists: return "Подходящих исполнителей не найдено"
        case .albums: return "Нет данных об альбомах"
        case .favorites: return "В избранном пока нет треков"
        case .recent: return "Вы ещё ничего не слушали"
        case .queue: return "Очередь пуста"
        case .playlists: return library.playlists.isEmpty ? "Плейлистов пока нет" : "Плейлист пуст"
        }
    }

    private var emptyIcon: String {
        switch selectedSection {
        case .all: return "magnifyingglass"
        case .artists: return "person.2"
        case .albums: return "square.stack"
        case .favorites: return "heart"
        case .recent: return "clock"
        case .queue: return "text.line.first.and.arrowtriangle.forward"
        case .playlists: return "rectangle.stack"
        }
    }

    private func trackSubtitle(_ track: Track) -> String {
        if selectedSection == .recent, let lastPlayedAt = track.lastPlayedAt {
            return "Прослушан \(lastPlayedAt.formatted(date: .abbreviated, time: .shortened))"
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
