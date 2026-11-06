import SwiftUI

struct StudioPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct StudioSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    @Environment(\.carAmbientTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title)).font(.system(.title3, weight: .semibold)).foregroundStyle(theme.ink)
            if let subtitle { Text(LocalizedStringKey(subtitle)).font(.caption).foregroundStyle(theme.mutedInk) }
        }
    }
}

struct StudioBottomNavigation: View {
    @Binding var selection: Int
    @Environment(\.carAmbientTheme) private var theme
    private let items = [(0, "Home", "house"), (1, "Library", "square.stack"), (4, "Player", "play.circle"), (2, "Equalizer", "slider.vertical.3"), (3, "Settings", "gearshape")]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { id, title, icon in
                Button { selection = id } label: {
                    VStack(spacing: 6) {
                        Image(systemName: icon).font(.system(size: 21, weight: selection == id ? .semibold : .regular))
                            .symbolVariant(selection == id ? .fill : .none)
                        Text(LocalizedStringKey(title)).font(.system(size: 10, weight: selection == id ? .semibold : .regular))
                    }
                    .foregroundStyle(selection == id ? theme.accent : theme.mutedInk)
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StudioPressStyle())
                .accessibilityAddTraits(selection == id ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 12).padding(.top, 4)
        .background(theme.background)
    }
}

struct StudioPlayerControls: View {
    @ObservedObject var audio: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @Environment(\.carAmbientTheme) private var theme
    var body: some View {
        HStack(spacing: 0) {
            button("Shuffle", "shuffle", active: library.isShuffleEnabled) { library.isShuffleEnabled.toggle() }
            Spacer(minLength: 0)
            button("Previous", "backward.end.fill") { library.playPrevious(audioManager: audio) }
            Spacer(minLength: 0)
            Button {
                if audio.currentTrackID == nil, let first = library.tracks(for: library.playbackIDs).first {
                    library.play(first, audioManager: audio)
                } else { audio.togglePlayPause() }
            } label: {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 25, weight: .semibold)).contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(theme.onAccent).frame(width: 72, height: 72)
                    .background(theme.accent, in: Circle())
                    .shadow(color: theme.accent.opacity(theme.isDark ? 0.12 : 0.06), radius: 20)
            }
            .accessibilityLabel(audio.isPlaying ? "Pause" : "Play")
            .disabled(audio.currentTrackID == nil && library.playbackIDs.isEmpty)
            Spacer(minLength: 0)
            button("Next", "forward.end.fill") { library.playNext(audioManager: audio) }
            Spacer(minLength: 0)
            button("Повтор: \(library.repeatMode.localizedTitle)", library.repeatMode == .one ? "repeat.1" : "repeat", active: library.repeatMode != .off) {
                switch library.repeatMode { case .off: library.repeatMode = .all; case .all: library.repeatMode = .one; case .one: library.repeatMode = .off }
            }
        }.buttonStyle(StudioPressStyle())
    }
    private func button(_ title: String, _ icon: String, active: Bool? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: active == nil ? 23 : 18))
                Circle().fill(active == true ? theme.accent : .clear).frame(width: 3, height: 3)
            }
            .foregroundStyle(active == false ? theme.mutedInk : theme.ink)
            .frame(width: 44, height: 52)
        }.accessibilityLabel(Text(LocalizedStringKey(title)))
    }
}

struct StudioWaveformSeek: View {
    @ObservedObject var audio: AudioEngineManager
    @Environment(\.carAmbientTheme) private var theme
    @State private var pending: Double?
    private var progress: Double { pending ?? min(max(audio.currentTime / max(audio.duration, 0.01), 0), 1) }
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                Canvas { context, size in
                    let samples = audio.waveformSamples
                    let count = max(1, Int(size.width / 4))
                    for index in 0..<count {
                        let sample = samples.isEmpty ? Float(0.1) : samples[min(samples.count - 1, index * samples.count / count)]
                        let height = max(3, CGFloat(min(max(abs(sample), 0.03), 1)) * (size.height - 8))
                        let rect = CGRect(x: CGFloat(index) * size.width / CGFloat(count), y: (size.height - height) / 2, width: 2, height: height)
                        context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(Double(index) / Double(count) <= progress ? theme.ink : theme.mutedInk.opacity(0.3)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    guard audio.duration > 0 else { return }
                    pending = min(max(value.location.x / max(geometry.size.width, 1), 0), 1)
                }.onEnded { _ in
                    if let pending { audio.seek(to: pending * audio.duration) }
                    pending = nil
                })
                .accessibilityElement().accessibilityLabel("Playback position")
                .accessibilityValue(time(progress * audio.duration))
                .accessibilityAdjustableAction { direction in
                    audio.seek(to: audio.currentTime + (direction == .increment ? 5 : -5))
                }
            }.frame(height: 48)
            HStack { Text(time(progress * audio.duration)); Spacer(); Text(time(audio.duration)) }
                .font(.caption.monospacedDigit()).foregroundStyle(theme.mutedInk)
        }
    }
    private func time(_ value: Double) -> String {
        let seconds = value.isFinite ? max(0, Int(value)) : 0
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct StudioPresetSelector: View {
    @ObservedObject var audio: AudioEngineManager
    @ObservedObject var presets: PresetManager
    @Environment(\.carAmbientTheme) private var theme
    var body: some View {
        Menu {
            Button("Flat EQ") { audio.applyGains(Array(repeating: 0, count: audio.bandCount)) }
            ForEach(presets.presets) { preset in
                Button { presets.apply(preset, to: audio) } label: {
                    Label(preset.name, systemImage: presets.activePresetID == preset.id ? "checkmark" : preset.category.systemImage)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3").foregroundStyle(theme.mutedInk)
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRESET").font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(theme.mutedInk)
                    Text(presets.presets.first { $0.id == presets.activePresetID }?.name ?? "Custom EQ")
                        .font(.subheadline.weight(.medium)).lineLimit(1).foregroundStyle(theme.ink)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(theme.mutedInk)
            }.padding(16).background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct StudioTrackIdentity: View {
    let track: Track
    var number: Int? = nil
    var current = false
    @Environment(\.carAmbientTheme) private var theme
    var body: some View {
        HStack(spacing: 12) {
            if let number {
                Group {
                    if current { Image(systemName: "waveform") }
                    else { Text(String(format: "%02d", number)).font(.caption.monospacedDigit()) }
                }.foregroundStyle(current ? theme.ink : theme.mutedInk).frame(width: 22)
            }
            TrackArtwork(track: track, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(track.title).font(.subheadline.weight(.medium)).foregroundStyle(theme.ink).lineLimit(1)
                Text(track.artistDisplayName + " · " + duration).font(.caption).foregroundStyle(theme.mutedInk).lineLimit(1)
            }
            Spacer(minLength: 4)
        }.contentShape(Rectangle())
    }
    private var duration: String {
        let seconds = track.duration.isFinite ? max(Int(track.duration), 0) : 0
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
