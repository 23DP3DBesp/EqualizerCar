import SwiftUI

struct RetroDashboardView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presetManager: PresetManager
    @Environment(\.carAmbientTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            retroBackground

            VStack(spacing: 18) {
                header
                headUnitDisplay
                RetroVUMeterView(levels: audioManager.spectrumLevels)
                    .frame(height: 86)
                transportCluster
                statusStrip
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 26)
        }
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height > 90 { dismiss() }
            }
        )
    }

    private var retroBackground: some View {
        LinearGradient(
            colors: [
                theme.accent.opacity(0.18),
                theme.background,
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("EQUALIZERCAR")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .tracking(2)
                .foregroundStyle(theme.accent)
                .themedGlow(radius: 8)

            Spacer()

            Menu {
                Button { audioManager.safeLoudModeEnabled.toggle() } label: {
                    Label("Headroom Guard", systemImage: "shield")
                }
                Button { cycleRepeatMode() } label: {
                    Label("Repeat: \(library.repeatMode.rawValue)", systemImage: "repeat")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(theme.ink)
    }

    private var headUnitDisplay: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(audioManager.isPlaying ? "AUX INPUT" : "STANDBY")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .tracking(1.6)
                Spacer()
                Text(formatTime(audioManager.currentTime))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
            }
            .foregroundStyle(theme.secondaryAccent)

            Text(audioManager.currentTrackTitle.uppercased())
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .lineLimit(2)
                .minimumScaleFactor(0.58)
                .foregroundStyle(theme.accent)
                .themedGlow(radius: 12)
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)

            RetroSegmentProgressView(progress: progress)
                .frame(height: 20)

            HStack {
                Text("VOL \(Int(audioManager.outputGain * 100))")
                Spacer()
                Text(library.isShuffleEnabled ? "RND" : "SEQ")
                Text(library.repeatMode == .off ? "REP OFF" : "REP \(library.repeatMode.rawValue.uppercased())")
            }
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .foregroundStyle(theme.mutedInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.accent.opacity(0.44), lineWidth: 1.2)
                )
        )
    }

    private var transportCluster: some View {
        HStack(spacing: 14) {
            tactileButton(icon: "shuffle", isActive: library.isShuffleEnabled) {
                library.isShuffleEnabled.toggle()
            }
            tactileButton(icon: "backward.end.fill") {
                audioManager.previousTrackRequested?()
            }
            tactileButton(icon: audioManager.isPlaying ? "pause.fill" : "play.fill", prominent: true) {
                audioManager.togglePlayPause()
            }
            .disabled(audioManager.duration <= 0)
            tactileButton(icon: "forward.end.fill") {
                audioManager.nextTrackRequested?()
            }
            tactileButton(icon: "shield.fill", isActive: audioManager.safeLoudModeEnabled) {
                audioManager.safeLoudModeEnabled.toggle()
            }
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            statusPill("PRESET", value: presetName)
            statusPill("LEVEL", value: "\(Int(audioManager.currentLevel * 100))%")
        }
    }

    private func tactileButton(icon: String, prominent: Bool = false, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: prominent ? 28 : 18, weight: .black))
                .foregroundStyle(prominent || isActive ? .black : theme.accent)
                .frame(width: prominent ? 72 : 52, height: prominent ? 72 : 52)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(prominent || isActive ? theme.accent : theme.surface.opacity(0.88))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.accent.opacity(0.45), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .themedGlow(radius: prominent || isActive ? 10 : 4)
    }

    private func statusPill(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(theme.mutedInk)
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(theme.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var presetName: String {
        guard let id = presetManager.activePresetID,
              let preset = presetManager.presets.first(where: { $0.id == id }) else {
            return "MANUAL"
        }
        return preset.name.uppercased()
    }

    private var progress: Double {
        guard audioManager.duration > 0 else { return 0 }
        return min(max(audioManager.currentTime / audioManager.duration, 0), 1)
    }

    private func cycleRepeatMode() {
        switch library.repeatMode {
        case .off: library.repeatMode = .all
        case .all: library.repeatMode = .one
        case .one: library.repeatMode = .off
        }
    }

    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "0:00" }
        let totalSeconds = max(Int(time), 0)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct RetroSegmentProgressView: View {
    @Environment(\.carAmbientTheme) private var theme
    let progress: Double
    private let segmentCount = 28

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segmentCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Double(index) / Double(segmentCount) <= progress ? theme.accent : theme.surface.opacity(0.8))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct RetroVUMeterView: View {
    @Environment(\.carAmbientTheme) private var theme
    let levels: [Float]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(displayLevels.enumerated()), id: \.offset) { index, level in
                    let normalized = CGFloat(min(max(level, 0), 1))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index > displayLevels.count - 4 ? theme.secondaryAccent : theme.accent)
                        .frame(width: max((proxy.size.width - 60) / CGFloat(displayLevels.count), 4), height: max(proxy.size.height * normalized, 4))
                        .opacity(0.42 + normalized * 0.58)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(10)
        .background(Color.black.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.accent.opacity(0.28), lineWidth: 1)
        )
    }

    private var displayLevels: [Float] {
        let source = levels.isEmpty ? Array(repeating: Float(0.05), count: 16) : levels
        return Array(source.prefix(16))
    }
}

#Preview {
    RetroDashboardView(
        audioManager: AudioEngineManager(),
        library: LibraryManager(),
        presetManager: PresetManager()
    )
    .carAmbientTheme(ThemeManager())
    .preferredColorScheme(.light)
}
