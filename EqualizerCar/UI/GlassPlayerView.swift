import SwiftUI

struct NeumorphicButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12
    var backgroundColor: Color = AppTheme.liquidGlassDark.panelTint

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .liquidGlassPanel(cornerRadius: cornerRadius, tint: backgroundColor, interactive: true)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlassPlayerView: View {
    @EnvironmentObject var audioManager: AudioEngineManager
    @EnvironmentObject var library: LibraryManager
    @EnvironmentObject var presetManager: PresetManager
    @Environment(\.carAmbientTheme) private var theme
    @State private var isVisible = false
    @State private var playPulse = false
    @State private var showNowPlaying = false

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 380
            let artworkSize = min(max(geo.size.width * (isCompact ? 0.38 : 0.34), 100), 220)

            ZStack {
                theme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: isCompact ? 12 : 18) {
                    header

                    HStack(spacing: 16) {
                        artwork(size: artworkSize)
                            .onTapGesture {
                                showNowPlaying = true
                            }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(audioManager.currentTrackTitle)
                                .font(isCompact ? .headline : .title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.ink)
                                .lineLimit(2)

                            Text("Artist")
                                .font(.subheadline)
                                .foregroundStyle(theme.mutedInk)

                            progress
                        }
                    }
                    .padding(.horizontal, isCompact ? 14 : 20)

                    controls
                        .padding(.bottom, isCompact ? 6 : 12)
                }
                .padding(.top, isCompact ? 12 : 18)
                .padding(.vertical, 12)
                .frame(maxWidth: 760)
                .padding(.horizontal, isCompact ? 12 : 20)
                .liquidGlassPanel(cornerRadius: 28, tint: theme.surface.opacity(theme.glassOpacity))
                .scaleEffect(isVisible ? 1 : 0.995)
                .opacity(isVisible ? 1 : 0)
                .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.8, blendDuration: 0.2), value: isVisible)
                .onAppear {
                    isVisible = true
                    if audioManager.isPlaying { playPulse = true }
                }
                .fullScreenCover(isPresented: $showNowPlaying) {
                    NowPlayingView(
                        audioManager: audioManager,
                        library: library,
                        presetManager: presetManager
                    )
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: { showNowPlaying = true }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundStyle(theme.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(NeumorphicButtonStyle(cornerRadius: 18))

            Spacer()

            Text("Listen now")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.mutedInk)

            Spacer()

            Button(action: { showNowPlaying = true }) {
                Image(systemName: "waveform")
                    .foregroundStyle(theme.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(NeumorphicButtonStyle(cornerRadius: 18))
        }
        .padding(.horizontal)
    }

    private func artwork(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.surface.opacity(0.96))
                .frame(width: size, height: size)
                .overlay(
                    Group {
                        if let image = artworkImage() {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        } else {
                            theme.surface.opacity(theme.glassOpacity)
                                .frame(width: size, height: size)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(Text("No Art").foregroundStyle(theme.mutedInk))
                        }
                    }
                )
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        }
    }

    private var progress: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: {
                audioManager.currentTime / max(audioManager.duration, 1)
            }, set: { newVal in
                let t = Double(newVal) * (audioManager.duration)
                audioManager.seek(to: t)
            }))
            .tint(theme.secondaryAccent)

            HStack {
                Text(formattedTime(audioManager.currentTime))
                    .font(.caption)
                Spacer()
                Text(formattedTime(audioManager.duration))
                    .font(.caption)
            }
            .foregroundStyle(theme.mutedInk)
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Button(action: { audioManager.previousTrackRequested?() }) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundStyle(theme.ink)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(NeumorphicButtonStyle(cornerRadius: 28))

            Button(action: { audioManager.togglePlayPause(); playPulse.toggle() }) {
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 76, height: 76)
                    .background(
                        Circle()
                            .fill(LinearGradient(colors: [theme.secondaryAccent, theme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: theme.accent.opacity(0.35), radius: 22, x: 0, y: 12)
                    )
            }
            .scaleEffect(playPulse ? 1.02 : 1)
            .animation(audioManager.isPlaying ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: playPulse)

            Button(action: { audioManager.nextTrackRequested?() }) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(theme.ink)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(NeumorphicButtonStyle(cornerRadius: 28))
        }
    }

    private func formattedTime(_ sec: Double) -> String {
        guard sec.isFinite && sec > 0 else { return "0:00" }
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func artworkImage() -> UIImage? {
        // Try to extract artwork from audioManager's current track if available
        // Placeholder: integrate with LibraryManager/Track to load artwork image
        return nil
    }
}

struct GlassPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        GlassPlayerView()
            .environmentObject(AudioEngineManager())
            .environmentObject(LibraryManager())
            .environmentObject(PresetManager())
            .previewDevice("iPhone 15")
    }
}
