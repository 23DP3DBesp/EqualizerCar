import SwiftUI

struct PlayerDashboardView: View {
    @ObservedObject var audioManager: AudioEngineManager

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                nowPlayingHeader
                waveformPanel
                transportControls
                meterPanel
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.07),
                    Color(red: 0.08, green: 0.10, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Player")
    }

    private var nowPlayingHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(audioManager.isPlaying ? "Playing" : "Ready", systemImage: audioManager.isPlaying ? "waveform" : "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(audioManager.isPlaying ? .cyan : .secondary)

                Spacer()

                if audioManager.isOverloaded {
                    Label("Overload", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }

                Text(durationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(audioManager.currentTrackTitle)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            LevelMeterView(level: audioManager.currentLevel)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var waveformPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Waveform")
                    .font(.headline)
                Spacer()
                Text(progressText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            PlaybackProgressView(audioManager: audioManager)
                .padding(.horizontal, -12)
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var transportControls: some View {
        HStack(spacing: 26) {
            Button {
                audioManager.seek(to: audioManager.currentTime - 15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
            }
            .disabled(audioManager.duration <= 0)

            Button {
                audioManager.togglePlayPause()
            } label: {
                Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 76))
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(audioManager.duration <= 0)

            Button {
                audioManager.seek(to: audioManager.currentTime + 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.title2)
            }
            .disabled(audioManager.duration <= 0)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var meterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spectrum")
                .font(.headline)

            SpectrumAnalyzerView(levels: audioManager.spectrumLevels)
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var progressText: String {
        "\(formatTime(audioManager.currentTime)) / \(formatTime(audioManager.duration))"
    }

    private var durationText: String {
        audioManager.duration > 0 ? formatTime(audioManager.duration) : "0:00"
    }

    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "0:00" }
        let totalSeconds = max(Int(time), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
