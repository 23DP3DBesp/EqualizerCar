import SwiftUI
import UniformTypeIdentifiers

struct LibraryCleanupView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @Environment(\.carAmbientTheme) private var theme
    @State private var issues: [LibraryManager.LibraryHealthIssue] = []
    @State private var selectedTrackIDs = Set<UUID>()
    @State private var isScanning = false
    @State private var showDeleteConfirmation = false
    @State private var showAudioImporter = false
    @State private var trackToReplace: Track?
    @State private var scanCompleted = false

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scanCompleted ? "\(issues.count) issues found" : "Check your audio library")
                            .font(.headline)
                        Text("Checks missing files, audio readability, duration and track tags.")
                            .font(.caption).foregroundStyle(theme.mutedInk)
                    }
                    Spacer()
                    Button { Task { await scan() } } label: {
                        if isScanning { ProgressView() }
                        else { Label("Scan", systemImage: "arrow.clockwise") }
                    }
                    .disabled(isScanning)
                }
                if isScanning { ProgressView("Scanning library…") }
            }

            if scanCompleted {
                Section("Library health") {
                    if issues.isEmpty {
                        Label("No problems found", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        ForEach(issues) { issue in issueRow(issue) }
                    }
                }
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unorganized tracks")
                            .font(.headline)
                        Text("Not in any playlist and not marked as favorite.")
                            .font(.caption).foregroundStyle(theme.mutedInk)
                    }
                    Spacer()
                    Text("\(library.unusedTracks.count)").font(.caption.monospacedDigit())
                }
                if library.unusedTracks.isEmpty {
                    Text("No unorganized tracks.").font(.caption).foregroundStyle(theme.mutedInk)
                } else {
                    Button {
                        selectedTrackIDs.formUnion(library.unusedTracks.map(\.id))
                    } label: { Label("Select all unorganized", systemImage: "checkmark.circle") }
                    ForEach(library.unusedTracks) { track in
                        trackSelectionRow(track, subtitle: "\(track.artistDisplayName) · \(track.album ?? "No album")")
                    }
                }
            }

            if !selectedTrackIDs.isEmpty {
                Section {
                    Button(role: .destructive) { showDeleteConfirmation = true } label: {
                        Label("Delete selected tracks (\(selectedTrackIDs.count))", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if let message = library.importErrorMessage {
                Section("Last operation") { Text(message).foregroundStyle(.red).font(.footnote) }
            }
        }
        .navigationTitle("Library Cleanup")
        .scrollContentBackground(.hidden)
        .background(theme.screenBackground)
        .task { await scan() }
        .alert("Delete selected tracks?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteSelected() }
        } message: {
            Text("Audio files and playlist references will be removed. Favorites will also be removed if selected.")
        }
        .fileImporter(isPresented: $showAudioImporter, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first, let track = trackToReplace else { return }
            if audioManager.currentTrackID == track.id { audioManager.unloadCurrentTrack() }
            _ = library.replaceAudioFile(for: track, with: url)
            trackToReplace = nil
            Task { await scan() }
        }
    }

    @ViewBuilder
    private func issueRow(_ issue: LibraryManager.LibraryHealthIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            trackSelectionRow(issue.track, subtitle: issueDescription(issue.kind))
            HStack {
                switch issue.kind {
                case .invalidDuration:
                    Button("Repair duration") {
                        Task {
                            _ = await library.repairDuration(for: issue.track)
                            await scan()
                        }
                    }
                case .incompleteMetadata, .unreadableMetadata:
                    Button("Read tags again") {
                        library.refreshMetadata(for: issue.track)
                    }
                case .missingFile, .unreadableAudio:
                    EmptyView()
                }
                Button("Replace file") {
                    trackToReplace = issue.track
                    showAudioImporter = true
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
        }
    }

    private func trackSelectionRow(_ track: Track, subtitle: String) -> some View {
        Button {
            if selectedTrackIDs.contains(track.id) { selectedTrackIDs.remove(track.id) }
            else { selectedTrackIDs.insert(track.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedTrackIDs.contains(track.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedTrackIDs.contains(track.id) ? theme.accent : theme.mutedInk)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title.isEmpty ? track.fileName : track.title).foregroundStyle(theme.ink).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(theme.mutedInk).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func issueDescription(_ kind: LibraryManager.LibraryIssueKind) -> String {
        switch kind {
        case .missingFile: return "Audio file is missing from the app library."
        case .unreadableAudio: return "Audio file could not be opened or has no playable frames."
        case .invalidDuration: return "Saved duration is empty or invalid; it can be recalculated from the file."
        case .unreadableMetadata: return "Audio metadata could not be read. Try refreshing tags or replacing the file."
        case .incompleteMetadata: return "Title, artist or album tags are incomplete."
        }
    }

    private func deleteSelected() {
        let selected = library.tracks.filter { selectedTrackIDs.contains($0.id) }
        if selected.contains(where: { $0.id == audioManager.currentTrackID }) { audioManager.unloadCurrentTrack() }
        library.deleteTracks(selected)
        selectedTrackIDs.removeAll()
        Task { await scan() }
    }

    @MainActor
    private func scan() async {
        isScanning = true
        issues = await library.scanLibraryHealth()
        scanCompleted = true
        isScanning = false
    }
}
