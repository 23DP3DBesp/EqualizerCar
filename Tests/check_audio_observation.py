"""Verify production telemetry does not broadcast through the root audio manager."""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[1] / 'EqualizerCar/AudioEngine/AudioEngineManager.swift').read_text()
telemetry = source[source.index('@MainActor\n@Observable\nfinal class AudioTelemetry'):]
start = source.index('    let telemetry = AudioTelemetry()')
end = source.index('    @Published var duration:', start)
accessors = source[start:end]
program = '''import Foundation
import Combine
import Observation
''' + telemetry + '''
@MainActor
final class AudioSpy: ObservableObject {
    @Published var isPlaying = false
''' + accessors + '''
}
@MainActor
func verify() {
    let manager = AudioSpy()
    var rootNotifications = 0
    let subscription = manager.objectWillChange.sink { rootNotifications += 1 }
    final class Flag: @unchecked Sendable { var changed = false }
    let meter = Flag()
    let progress = Flag()
    withObservationTracking { _ = manager.currentLevel } onChange: { meter.changed = true }
    withObservationTracking { _ = manager.currentTime } onChange: { progress.changed = true }
    for index in 1...1000 {
        manager.currentLevel = Float(index) / 1000
        manager.spectrumLevels = [Float(index)]
    }
    assert(meter.changed)
    assert(!progress.changed, "Meter changes invalidated playback progress")
    assert(rootNotifications == 0, "Meter changes broadcast to all screens")
    manager.currentTime = 1
    assert(progress.changed)
    assert(rootNotifications == 0, "Progress tick broadcast to all screens")
    manager.isPlaying = true
    assert(rootNotifications == 1, "Playback controls stopped observing state")
    withExtendedLifetime(subscription) {}
    print("PASS: 1000 meter ticks / 0 root broadcasts; progress and playback controls still notify their observers")
}
MainActor.assumeIsolated { verify() }
'''
with tempfile.TemporaryDirectory(prefix='music-observation-') as tmp:
    path = Path(tmp) / 'Check.swift'
    path.write_text(program)
    subprocess.run(['swift', '-module-cache-path', '/tmp/music-swift-module-cache', str(path)], check=True)
