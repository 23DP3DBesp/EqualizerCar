"""Check old preset decoding and round-trip of all effect fields using production models."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
model = (root / 'EqualizerCar/Models/Preset.swift').read_text()
manager = (root / 'EqualizerCar/Presets/PresetManager.swift').read_text()
start = manager.index('    private static func normalizedEffects(')
end = manager.index('    private func saveProfileHistoryIfNeeded', start)
normalizer = manager[start:end].replace('private static', 'static')
checks = r'''
let decoder = JSONDecoder()
let old = try decoder.decode(PresetEffectSettings.self, from: Data("{\"limiterEnabled\":true}".utf8))
assert(old.limiterEnabled && !old.tapeSaturationEnabled && !old.transientShaperEnabled && !old.parametricNotchEnabled)
let effects = PresetEffectSettings(parametricNotchEnabled: true, parametricNotchFrequency: 3456,
    parametricNotchQ: 7, parametricNotchDepth: -24,
    subsonicEnabled: true, subsonicCutoff: 42, vocalClarityEnabled: true, vocalClarityAmount: 0.7,
    nightModeEnabled: true, nightModeAmount: 0.8, tapeSaturationEnabled: true,
    tapeSaturationDrive: 0.72, tapeSaturationMix: 0.81, transientShaperEnabled: true,
    transientAttack: 9, transientSustain: -8, softClipperDrive: 0.61)
let normalized = Normalizer.normalizedEffects(effects)
assert(normalized == effects, "Normalization lost effect settings")
let data = try JSONEncoder().encode(effects)
let decoded = try decoder.decode(PresetEffectSettings.self, from: data)
let originalFields = Array(Mirror(reflecting: effects).children)
let decodedFields = Array(Mirror(reflecting: decoded).children)
for (a,b) in zip(originalFields, decodedFields) {
    if String(describing: a.value) != String(describing: b.value) { print("Mismatch: \(a.label ?? "?") \(a.value) -> \(b.value)") }
}
assert(decoded == effects, "Effect settings did not round-trip")
print("PASS: old presets, normalization and new effect round-trip")
'''
with tempfile.TemporaryDirectory() as temporary:
    source = Path(temporary) / 'main.swift'
    source.write_text('enum CrossoverMode: String, Codable, Sendable { case subwoofer, speakers }\n' + model + '\nstruct Normalizer {\n' + normalizer + '\n}\n' + checks)
    executable = Path(temporary) / 'checks'
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(Path(temporary) / 'modules'), str(source), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
