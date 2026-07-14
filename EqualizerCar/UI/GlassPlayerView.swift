import SwiftUI

struct NeumorphicButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12
    var backgroundColor: Color = Color.white.opacity(0.9)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
                    .shadow(color: Color.black.opacity(configuration.isPressed ? 0.05 : 0.08), radius: configuration.isPressed ? 4 : 14, x: configuration.isPressed ? 1 : 6, y: configuration.isPressed ? 1 : 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                            .blendMode(.overlay)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlassPlayerView: View {
    @EnvironmentObject var audioManager: AudioEngineManager
    @State private var isVisible = false
    @State private var playPulse = false

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 380
            let artworkSize = min(max(geo.size.width * (isCompact ? 0.38 : 0.34), 100), 220)

            ZStack {
                // soft background blur for glass effect
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: isCompact ? 12 : 18) {
                    header

                    HStack(spacing: 16) {
                        artwork(size: artworkSize)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(audioManager.currentTrackTitle)
                                .font(isCompact ? .headline : .title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(2)

                            Text("Artist")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

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
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0.70)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.6), lineWidth: 0.6)
                                .blur(radius: 0.3)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 30, x: 0, y: 14)
                        .padding(.horizontal, isCompact ? 12 : 20)
                )
                .scaleEffect(isVisible ? 1 : 0.995)
                .opacity(isVisible ? 1 : 0)
                .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.8, blendDuration: 0.2), value: isVisible)
                .onAppear {
                    isVisible = true
                    if audioManager.isPlaying { playPulse = true }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: { /* TODO: close */ }) {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(NeumorphicButtonStyle(cornerRadius: 18))

            Spacer()

            Text("Listen now")
                .font(.subheadline).foregroundColor(.secondary)

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(NeumorphicButtonStyle(cornerRadius: 18))
        }
        .padding(.horizontal)
    }

    private func artwork(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.9))
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
                            Color.gray.opacity(0.3)
                                .frame(width: size, height: size)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(Text("No Art").foregroundColor(.secondary))
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

            HStack {
                Text(formattedTime(audioManager.currentTime))
                    .font(.caption)
                Spacer()
                Text(formattedTime(audioManager.duration))
                    .font(.caption)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Button(action: { audioManager.previousTrackRequested?() }) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(NeumorphicButtonStyle(cornerRadius: 28))

            Button(action: { audioManager.togglePlayPause(); playPulse.toggle() }) {
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(Color.red))
            }
            .scaleEffect(playPulse ? 1.02 : 1)
            .animation(audioManager.isPlaying ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: playPulse)

            Button(action: { audioManager.nextTrackRequested?() }) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
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
            .previewDevice("iPhone 15")
    }
}
