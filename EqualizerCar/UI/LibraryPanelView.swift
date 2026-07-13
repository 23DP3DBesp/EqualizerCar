import SwiftUI

struct LibraryPanelView: View {
    private enum LibrarySection: String, CaseIterable, Identifiable {
        case all = "All"
        case favorites = "Favorites"
        case recent = "Recent"
        case queue = "Queue"

        var id: String { rawValue }
    }

    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @Binding var showFilePicker: Bool
    let importBackupAction: () -> Void
    let exportBackupAction: () -> Void

    @State private var selectedSection: LibrarySection = .all
    @State private var renamingTrack: Track?
    @State private var renameTitle = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                playbackOptions

                if library.isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Importing track...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                if let importErrorMessage = library.importErrorMessage {
                    Text(importErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if library.tracks.isEmpty {
                    emptyState
                } else {
                    Picker("Library section", selection: $selectedSection) {
                        ForEach(LibrarySection.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedSection != .queue {
                        TextField("Search tracks", text: $library.searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                    }

                    if visibleTracks.isEmpty {
                        ContentUnavailableView(emptyTitle, systemImage: emptyIcon)
                            .padding(.top, 24)
                    } else {
                        trackList
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Library")
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
    }

    private var header: some View {
        HStack {
            Text("Tracks")
                .font(.headline)
            Spacer()
            Button(action: importBackupAction) {
                Image(systemName: "square.and.arrow.down")
                    .font(.title3)
            }
            Button(action: exportBackupAction) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
            }
            Button {
                showFilePicker = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
        }
    }

    private var playbackOptions: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $library.isShuffleEnabled) {
                Image(systemName: "shuffle")
            }
            .toggleStyle(.button)

            Picker("Repeat", selection: $library.repeatMode) {
                ForEach(LibraryManager.RepeatMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Button {
                library.playNext(audioManager: audioManager)
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .disabled(library.tracks.isEmpty)

            Spacer()

            if !library.queueIDs.isEmpty {
                Button("Clear Queue") {
                    library.clearQueue()
                }
                .font(.caption)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ContentUnavailableView(
                "No Tracks",
                systemImage: "music.note.list",
                description: Text("Import audio files from Files to process them in realtime.")
            )

            Button {
                showFilePicker = true
            } label: {
                Label("Add Track", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }

    private var trackList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(visibleTracks.enumerated()), id: \.offset) { _, track in
                trackRow(track)
                Divider()
            }
        }
    }

    private func trackRow(_ track: Track) -> some View {
        HStack(spacing: 12) {
            Button {
                library.play(track, audioManager: audioManager)
            } label: {
                Image(systemName: audioManager.currentTrackID == track.id ? "speaker.wave.2.fill" : "music.note")
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .lineLimit(1)
                    if selectedSection == .recent, let lastPlayedAt = track.lastPlayedAt {
                        Text(lastPlayedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .buttonStyle(.plain)

            Button {
                library.toggleFavorite(track)
            } label: {
                Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(track.isFavorite ? .pink : .secondary)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    library.addToQueue(track)
                } label: {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                }
                Button {
                    renamingTrack = track
                    renameTitle = track.title
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    if audioManager.currentTrackID == track.id {
                        audioManager.pause()
                    }
                    library.deleteTrack(track)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 13)
    }

    private var visibleTracks: [Track] {
        switch selectedSection {
        case .all:
            return library.filteredTracks
        case .favorites:
            return library.filteredTracks.filter(\.isFavorite)
        case .recent:
            let matchingIDs = Set(library.filteredTracks.map(\.id))
            return library.recentlyPlayedTracks.filter { matchingIDs.contains($0.id) }
        case .queue:
            return library.queueIDs.compactMap { id in
                library.tracks.first { $0.id == id }
            }
        }
    }

    private var emptyTitle: String {
        switch selectedSection {
        case .all:
            return "No Matching Tracks"
        case .favorites:
            return "No Favorite Tracks"
        case .recent:
            return "Nothing Played Yet"
        case .queue:
            return "Queue Is Empty"
        }
    }

    private var emptyIcon: String {
        switch selectedSection {
        case .all:
            return "magnifyingglass"
        case .favorites:
            return "heart"
        case .recent:
            return "clock"
        case .queue:
            return "text.line.first.and.arrowtriangle.forward"
        }
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
}
