import SwiftUI

struct PlaybackProgressView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @State private var pendingTime: Double = 0
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                WaveformProgressView(
                    samples: audioManager.waveformSamples,
                    progress: audioManager.duration > 0 ? (isEditing ? pendingTime : audioManager.currentTime) / audioManager.duration : 0
                )
                Slider(
                    value: Binding(
                        get: { isEditing ? pendingTime : audioManager.currentTime },
                        set: { pendingTime = $0 }
                    ),
                    in: 0...max(audioManager.duration, 0.01),
                    onEditingChanged: { editing in
                        isEditing = editing
                        if editing {
                            pendingTime = audioManager.currentTime
                        } else {
                            audioManager.seek(to: pendingTime)
                        }
                    }
                )
                .tint(.clear)
                .opacity(0.08)
                .disabled(audioManager.duration <= 0)
            }

            HStack {
                Text(formatTime(isEditing ? pendingTime : audioManager.currentTime))
                Spacer()
                Text(formatTime(audioManager.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "0:00" }
        let totalSeconds = max(Int(time), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
