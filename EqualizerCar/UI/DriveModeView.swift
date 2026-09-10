import SwiftUI

struct DriveModeView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presetManager: PresetManager
    @Environment(\.carAmbientTheme) private var theme
    let addMusicAction: () -> Void

    private let presetColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                nowPlayingPanel
                transportPanel
                quickPresetPanel
                meterPanel
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(theme.screenBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Drive Mode")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(theme.ink)
                Text(audioStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(audioManager.isOverloaded ? Color.red : theme.mutedInk)
            }

            Spacer()

            Button(action: addMusicAction) {
                Image(systemName: "plus")
                    .font(.title3.weight(.black))
                    .foregroundStyle(theme.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var nowPlayingPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    LinearGradient(
                        colors: [theme.accent, theme.secondaryAccent.opacity(0.55), Color.black.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: audioManager.isPlaying ? "waveform" : "music.note")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(.black.opacity(0.72))
                }
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(audioManager.isPlaying ? "PLAYING" : "READY")
                        .font(.caption.weight(.black))
                        .foregroundStyle(theme.accent)
                    Text(audioManager.currentTrackTitle)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(progressText)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(theme.mutedInk)
                }

                Spacer(minLength: 0)
            }

            ProgressView(value: progress)
                .tint(audioManager.isOverloaded ? .red : theme.accent)
                .scaleEffect(y: 1.35)
        }
        .padding(18)
        .background(theme.surface.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.accent.opacity(0.20), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var transportPanel: some View {
        HStack(spacing: 14) {
            transportButton(systemImage: "backward.fill", title: "PREV", size: .secondary) {
                audioManager.previousTrackRequested?()
            }

            transportButton(
                systemImage: audioManager.isPlaying ? "pause.fill" : "play.fill",
                title: audioManager.isPlaying ? "PAUSE" : "PLAY",
                size: .primary
            ) {
                audioManager.togglePlayPause()
            }
            .disabled(audioManager.duration <= 0)

            transportButton(systemImage: "forward.fill", title: "NEXT", size: .secondary) {
                audioManager.nextTrackRequested?()
            }
        }
    }

    private var quickPresetPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Presets")
                    .font(.headline.weight(.black))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text("5")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(theme.mutedInk)
            }

            LazyVGrid(columns: presetColumns, spacing: 10) {
                ForEach(Array(presetManager.quickPresets.prefix(5))) { preset in
                    Button {
                        presetManager.apply(preset, to: audioManager)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: preset.category.systemImage)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(presetManager.activePresetID == preset.id ? .black : theme.accent)
                                .frame(width: 34, height: 34)
                                .background(presetManager.activePresetID == preset.id ? theme.accent : Color.black.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                            Text(shortPresetName(preset.name))
                                .font(.caption.weight(.black))
                                .foregroundStyle(theme.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .frame(minHeight: 66)
                        .background(presetManager.activePresetID == preset.id ? theme.accent.opacity(0.18) : Color.black.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(presetManager.activePresetID == preset.id ? theme.accent.opacity(0.48) : Color.black.opacity(0.04), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(theme.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var meterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Volume / Clipping")
                    .font(.headline.weight(.black))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(meterStatus)
                    .font(.caption.weight(.black))
                    .foregroundStyle(meterColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [theme.secondaryAccent, theme.accent, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(levelFill))
                }
            }
            .frame(height: 34)

            HStack(spacing: 10) {
                metricTile("LEVEL", value: "\(Int(levelFill * 100))%", color: theme.ink)
                metricTile("PEAK", value: "\(Int(min(max(audioManager.overloadPeak, 0), 1) * 100))%", color: audioManager.overloadPeak > 0.92 ? .red : theme.ink)
                metricTile("CLIP", value: audioManager.isOverloaded ? "RISK" : "OK", color: audioManager.isOverloaded ? .red : theme.secondaryAccent)
            }
        }
        .padding(16)
        .background(theme.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private enum TransportButtonSize {
        case primary
        case secondary
    }

    private func transportButton(systemImage: String, title: String, size: TransportButtonSize, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: size == .primary ? 34 : 24, weight: .black))
                Text(title)
                    .font(.caption.weight(.black))
            }
            .foregroundStyle(size == .primary ? .black : theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: size == .primary ? 116 : 96)
            .background(size == .primary ? theme.accent : Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func metricTile(_ title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(theme.mutedInk)
            Text(value)
                .font(.title3.monospacedDigit().weight(.black))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var progress: Double {
        guard audioManager.duration > 0 else { return 0 }
        return min(max(audioManager.currentTime / audioManager.duration, 0), 1)
    }

    private var levelFill: Float {
        min(max(audioManager.currentLevel * 4, 0), 1)
    }

    private var meterStatus: String {
        if audioManager.isOverloaded { return "CLIPPING RISK" }
        if levelFill > 0.72 { return "LOUD" }
        return "CLEAN"
    }

    private var meterColor: Color {
        audioManager.isOverloaded ? .red : (levelFill > 0.72 ? theme.accent : theme.secondaryAccent)
    }

    private var audioStatusText: String {
        audioManager.isOverloaded ? "Reduce gain or enable protection" : "Large controls for driving"
    }

    private var progressText: String {
        "\(formatTime(audioManager.currentTime)) / \(formatTime(audioManager.duration))"
    }

    private func formatTime(_ time: Double) -> String {
        guard time.isFinite, time > 0 else { return "0:00" }
        let totalSeconds = Int(time)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func shortPresetName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "W211 ", with: "")
            .replacingOccurrences(of: "Mercedes ", with: "")
            .replacingOccurrences(of: "(AUX-Fix + Anti-Boom)", with: "AUX + Anti-Boom")
            .replacingOccurrences(of: "(Full Clarity)", with: "Clarity")
            .replacingOccurrences(of: "(Highs Recovery & Mono Punch)", with: "FM Recovery")
            .replacingOccurrences(of: "(Small Speakers)", with: "Small Speakers")
            .replacingOccurrences(of: "(Vocal & Clarity)", with: "Vocal Clarity")
    }
}

#Preview {
    DriveModeView(
        audioManager: AudioEngineManager(),
        library: LibraryManager(),
        presetManager: PresetManager(),
        addMusicAction: {}
    )
}
