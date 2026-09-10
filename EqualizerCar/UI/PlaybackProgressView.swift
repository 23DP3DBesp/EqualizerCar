import SwiftUI

struct PlaybackProgressView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.carAmbientTheme) private var theme
    @State private var pendingTime: Double = 0
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 6) {
            Group {
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
                .tint(theme.accent)
                .accessibilityLabel("Playback position")
                .disabled(audioManager.duration <= 0)
            }

            HStack {
                Text(formatTime(isEditing ? pendingTime : audioManager.currentTime))
                Spacer()
                Text(formatTime(audioManager.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(theme.mutedInk)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "0:00" }
        let totalSeconds = max(Int(time), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
