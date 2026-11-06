import SwiftUI
import AVFoundation
import UIKit

struct DeveloperToolsView: View {
    @ObservedObject var audio: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @Environment(\.carAmbientTheme) private var theme
    @State private var duplicateGroups: [[Track]] = []
    @State private var isScanning = false
    @State private var copiedReport = false

    private var missingTracks: [Track] { library.unavailableTracks }
    private var duplicateCopyCount: Int { duplicateGroups.reduce(0) { $0 + max($1.count - 1, 0) } }
    private var audioSession: AVAudioSession { .sharedInstance() }
    private var diagnosticReport: String {
        let outputs = audioSession.currentRoute.outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", ")
        return [
            "EqualizerCar Diagnostics",
            "App version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")",
            "Tracks: \(library.tracks.count)",
            "Playlists: \(library.playlists.count)",
            "Missing files: \(missingTracks.count)",
            "Audio engine: \(audio.isAudioEngineRunning ? "running" : "stopped")",
            "Sample rate: \(Int(audioSession.sampleRate)) Hz",
            "Output: \(outputs.isEmpty ? "none" : outputs)"
        ].joined(separator: "\n")
    }

    var body: some View {
        List {
            Section("Runtime") {
                LabeledContent("Audio engine", value: audio.isAudioEngineRunning ? "Running" : "Stopped")
                LabeledContent("Sample rate", value: "\(Int(audioSession.sampleRate)) Hz")
                LabeledContent("Output", value: audioSession.currentRoute.outputs.map(\.portName).joined(separator: ", ").isEmpty ? "None" : audioSession.currentRoute.outputs.map(\.portName).joined(separator: ", "))
                LabeledContent("Current track", value: audio.currentTrackTitle)
            }
            Section("Library integrity") {
                LabeledContent("Tracks", value: "\(library.tracks.count)")
                LabeledContent("Playlists", value: "\(library.playlists.count)")
                LabeledContent("Missing audio files", value: "\(missingTracks.count)")
                if !missingTracks.isEmpty {
                    ForEach(missingTracks) { track in
                        Label(track.title, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                Button {
                    isScanning = true
                    Task {
                        duplicateGroups = await library.findDuplicateTrackGroups()
                        isScanning = false
                    }
                } label: {
                    if isScanning { ProgressView("Scanning audio hashes…") }
                    else { Label("Scan for hash duplicates", systemImage: "doc.on.doc") }
                }
                .disabled(isScanning || library.tracks.count < 2)
                if !duplicateGroups.isEmpty {
                    LabeledContent("Duplicate groups", value: "\(duplicateGroups.count)")
                    LabeledContent("Extra copies", value: "\(duplicateCopyCount)")
                    ForEach(Array(duplicateGroups.enumerated()), id: \.offset) { entry in
                        let group = entry.element
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.first?.title ?? "Unknown track").font(.subheadline.weight(.semibold))
                            Text(group.map(\.fileName).joined(separator: " · ")).font(.caption2).foregroundStyle(theme.mutedInk)
                        }
                    }
                }
            }
            Section("Storage & reports") {
                Button { library.flushPendingStorage() } label: { Label("Flush pending library writes", systemImage: "externaldrive") }
                Button {
                    UIPasteboard.general.string = diagnosticReport
                    copiedReport = true
                } label: { Label(copiedReport ? "Report copied" : "Copy diagnostic report", systemImage: "doc.on.doc") }
                Text("Diagnostic report includes app version, library counts, audio route and sample rate.")
                    .font(.caption).foregroundStyle(theme.mutedInk)
            }
        }
        .navigationTitle("Developer Tools")
        .scrollContentBackground(.hidden)
        .background(theme.screenBackground)
    }
}
