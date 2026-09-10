"""Run production queue methods with an in-memory audio spy (no device or audio files).
Usage: python3 Tests/check_playback_queue.py
"""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[1] / 'EqualizerCar/Player/LibraryManager.swift').read_text()
def declaration(marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

methods = '\n'.join(declaration(x) for x in [
    'enum SortOption:', 'enum RepeatMode:', 'enum PlaybackSource:',
    'func selectPlaybackSource(', 'private func reconcilePlaybackQueue(',
    'func addToQueue(', 'func clearQueue(', 'func playNext(', 'func playPrevious(',
    'private func sortedTracks(',
])
fixture = r'''
import Foundation
struct Track {
    let id = UUID()
    var title: String
    var isFavorite = false
    var lastPlayedAt: Date? = nil
    var dateAdded = Date()
    var duration: Double = 1
}
struct AudioPlaylist { let id = UUID(); var trackIDs: [UUID] }
class AudioEngineManager {
    var currentTrackID: UUID?
    var paused = false
    func pause() { paused = true }
}
class LibraryManager {
    var tracks: [Track] = [] {
        didSet { trackIndexByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) }) }
    }
    var trackIndexByID: [UUID: Track] = [:]
    func refreshQueue() { reconcilePlaybackQueue() }
    var playlists: [AudioPlaylist] = []
    var playbackSource: PlaybackSource = .library
    var playbackIDs: [UUID] = []
    var playbackHistory: [UUID] = []
    var playbackQuery = ""
    var searchText = ""
    var queueIDs: [UUID] = []
    var repeatMode: RepeatMode = .off
    var sortOption: SortOption = .titleAscending
    var isShuffleEnabled = false
    func track(with id: UUID) -> Track? { trackIndexByID[id] }
    func tracks(for ids: [UUID]) -> [Track] { ids.compactMap { trackIndexByID[$0] } }
    func play(_ track: Track, audioManager: AudioEngineManager) {
        assert(playbackIDs.contains(track.id), "Escaped playback scope")
        audioManager.currentTrackID = track.id
        audioManager.paused = false
    }
'''
checks = r'''
let a = Track(title: "A", isFavorite: true)
let b = Track(title: "B")
let c = Track(title: "C", isFavorite: true)
let d = Track(title: "D")
let manager = LibraryManager()
manager.tracks = [a, b, c, d]
let audio = AudioEngineManager()
manager.selectPlaybackSource(.favorites, tracks: [a, c])
audio.currentTrackID = a.id
manager.playNext(audioManager: audio)
assert(audio.currentTrackID == c.id)
manager.playPrevious(audioManager: audio)
assert(audio.currentTrackID == a.id)
manager.playNext(audioManager: audio)
manager.playNext(audioManager: audio, automatically: true)
assert(audio.currentTrackID == c.id && audio.paused)
manager.repeatMode = .all
manager.playNext(audioManager: audio)
assert(audio.currentTrackID == a.id)
manager.playPrevious(audioManager: audio)
assert(audio.currentTrackID == c.id)
manager.repeatMode = .one
manager.playNext(audioManager: audio, automatically: true)
assert(audio.currentTrackID == c.id)
audio.currentTrackID = a.id
manager.playNext(audioManager: audio)
assert(audio.currentTrackID == c.id, "Manual Next must skip Repeat One")
manager.addToQueue(b)
assert(manager.queueIDs.isEmpty, "Out-of-scope overrides must be rejected")
manager.addToQueue(a)
manager.addToQueue(a)
assert(manager.queueIDs == [a.id])
manager.playNext(audioManager: audio)
assert(audio.currentTrackID == a.id && manager.queueIDs.isEmpty)
let playlist = AudioPlaylist(trackIDs: [d.id, b.id])
manager.playlists = [playlist]
manager.addToQueue(c)
manager.selectPlaybackSource(.playlist(playlist.id), tracks: [d, b])
assert(manager.queueIDs.isEmpty)
manager.repeatMode = .off
manager.playNext(audioManager: audio)
assert(audio.currentTrackID == d.id)
manager.playNext(audioManager: audio, automatically: true)
assert(audio.currentTrackID == b.id)
manager.playlists[0].trackIDs = [d.id]
manager.playNext(audioManager: audio)
assert(audio.currentTrackID == d.id && manager.playbackIDs == [d.id])
manager.playlists.removeAll()
manager.playNext(audioManager: audio, automatically: true)
assert(manager.playbackIDs.isEmpty && audio.paused)
manager.selectPlaybackSource(.selection, tracks: [])
manager.playNext(audioManager: audio)
assert(manager.playbackIDs.isEmpty)
manager.selectPlaybackSource(.favorites, tracks: [a, c])
manager.isShuffleEnabled = true
audio.currentTrackID = a.id
manager.playNext(audioManager: audio)
assert(audio.currentTrackID == c.id)
manager.playPrevious(audioManager: audio)
assert(audio.currentTrackID == a.id)
manager.repeatMode = .all
for _ in 0..<100 {
    manager.playNext(audioManager: audio, automatically: true)
    assert([a.id, c.id].contains(audio.currentTrackID!))
}
manager.tracks.removeAll { $0.id == c.id }
manager.playNext(audioManager: audio)
assert(manager.playbackIDs == [a.id])
manager.tracks[0].isFavorite = false
manager.playNext(audioManager: audio, automatically: true)
assert(manager.playbackIDs.isEmpty && audio.paused)
manager.isShuffleEnabled = false
manager.searchText = "B"
manager.selectPlaybackSource(.library, tracks: [b], query: manager.searchText)
manager.playNext(audioManager: audio)
assert(manager.playbackIDs == [b.id])
manager.tracks = [a, b, c, d]
manager.selectPlaybackSource(.favorites, tracks: [a, c])
manager.playNext(audioManager: audio)
assert(manager.playbackIDs == [a.id, c.id], "Home play ignores stale library search")
manager.selectPlaybackSource(.library, tracks: [], query: "missing")
manager.playNext(audioManager: audio, automatically: true)
assert(manager.playbackIDs.isEmpty && audio.paused)
let large = (0..<10_000).map { Track(title: "Track \($0)") }
manager.tracks = large
manager.selectPlaybackSource(.selection, tracks: Array(large.reversed()))
let start = Date()
for _ in 0..<20 { manager.refreshQueue() }
assert(manager.playbackIDs == large.reversed().map(\.id))
print("10,000 tracks / 20 queue reconciliations: \(Date().timeIntervalSince(start)) seconds")
print("PASS: Favorites, playlist order/switch/delete, empty lists, boundaries, repeat, manual queue, shuffle/history, track removal, search scope")
'''
with tempfile.TemporaryDirectory(prefix='music-queue-') as tmp:
    path = Path(tmp) / 'QueueChecks.swift'
    path.write_text(fixture + methods + '\n}\n' + checks)
    subprocess.run(['swift', '-module-cache-path', '/tmp/music-swift-module-cache', str(path)], check=True)
