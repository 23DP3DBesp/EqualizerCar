"""Check production coalesced writes preserve the newest snapshot and startup data."""
from pathlib import Path
import subprocess
import tempfile
source = (Path(__file__).resolve().parents[1] / 'EqualizerCar/Player/LibraryManager.swift').read_text()
def extract(marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]
program = '''import Foundation
@MainActor
final class StorageSpy {
    var tracks: [String] = []
    var isLoadingLibrary = false
    let storageQueue = DispatchQueue(label: "storage-check")
    var pendingIndexWrite: DispatchWorkItem?
    let indexFileURL: URL
    init(_ url: URL) { indexFileURL = url }
    func save() { saveIndex() }
''' + extract('private func saveIndex()') + '\n' + extract('func flushPendingStorage()') + '''
}
MainActor.assumeIsolated {
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    let store = StorageSpy(url)
    for i in 0..<100 { store.tracks = ["version-\\(i)"]; store.save() }
    store.flushPendingStorage()
    Thread.sleep(forTimeInterval: 0.3)
    let saved = try! JSONDecoder().decode([String].self, from: Data(contentsOf: url))
    assert(saved == ["version-99"], "A stale queued write replaced the final version")
    store.isLoadingLibrary = true
    store.tracks = []
    store.save()
    store.flushPendingStorage()
    let protected = try! JSONDecoder().decode([String].self, from: Data(contentsOf: url))
    assert(protected == saved, "Startup overwrote existing library with an empty snapshot")
    print("PASS: latest of 100 saves persists; background flush and startup guard preserve data")
}
'''
with tempfile.TemporaryDirectory(prefix='music-storage-') as tmp:
    path = Path(tmp) / 'Check.swift'
    path.write_text(program)
    subprocess.run(['swift', '-module-cache-path', '/tmp/music-swift-module-cache', str(path), str(Path(tmp) / 'index.json')], check=True)
