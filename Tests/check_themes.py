"""Run theme persistence and system-appearance checks on macOS."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
source = 'import Foundation\nimport SwiftUI\nMainActor.assumeIsolated {\n    let suite = "EqualizerCar.ThemeTests.\\(UUID().uuidString)"\n    let defaults = UserDefaults(suiteName: suite)!\n    defer { defaults.removePersistentDomain(forName: suite) }\n    let manager = ThemeManager(userDefaults: defaults)\n    assert(manager.appearance == .system)\n    manager.systemColorScheme = .dark\n    assert(manager.current.isDark)\n    manager.appearance = .day\n    assert(!manager.current.isDark && manager.current.backgroundColor.red == 1)\n    manager.appearance = .night\n    assert(manager.current.isDark)\n    let restored = ThemeManager(userDefaults: defaults)\n    assert(restored.appearance == .night && restored.current.isDark)\n    restored.appearance = .system\n    restored.systemColorScheme = .light\n    assert(!restored.current.isDark)\n    restored.systemColorScheme = .dark\n    assert(restored.current.isDark)\n    for palette in restored.availableThemes {\n        assert(palette.resolved(dark: true).isDark)\n        assert(!palette.resolved(dark: false).isDark)\n    }\n    print("PASS: day/night/system, persistence, all palettes")\n}\n'
with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    (work / "main.swift").write_text(source)
    subprocess.run(["xcrun", "swiftc", "-module-cache-path", str(work / "modules"),
        str(root / "EqualizerCar/UI/Themes/AppTheme.swift"),
        str(root / "EqualizerCar/UI/Themes/ThemeManager.swift"),
        str(work / "main.swift"), "-o", str(work / "checks")], check=True)
    subprocess.run([str(work / "checks")], check=True)
