import SwiftUI

struct LoudnessMeterView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.carAmbientTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Headroom / Loudness", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Spacer()
                Label(audioManager.limiterActive ? "Limiter Active" : "Limiter Idle", systemImage: audioManager.limiterActive ? "bolt.shield.fill" : "shield")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(audioManager.limiterActive ? theme.secondaryAccent : theme.mutedInk)
            }

            VStack(spacing: 10) {
                meterRow(title: "Input Peak", value: audioManager.inputPeak, text: dbText(audioManager.inputPeak), color: peakColor(audioManager.inputPeak))
                meterRow(title: "Output Peak", value: audioManager.outputPeak, text: dbText(audioManager.outputPeak), color: peakColor(audioManager.outputPeak))
                meterRow(title: "Clipping Risk", value: audioManager.clippingRisk, text: riskText, color: riskColor)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricTile(title: "LUFS approx", value: "\(String(format: "%.1f", audioManager.lufsApprox))")
                metricTile(title: "RMS", value: dbText(audioManager.rmsLevel))
                metricTile(title: "Dynamic Range", value: "\(String(format: "%.1f", audioManager.dynamicRange)) dB")
                metricTile(title: "Gain Reduction", value: "\(String(format: "%.1f", audioManager.gainReduction)) dB")
            }
        }
        .padding(14)
        .background(theme.surface.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(audioManager.clippingRisk > 0.72 ? theme.accent.opacity(0.55) : theme.accent.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.42), radius: 16, x: 0, y: 10)
    }

    private func meterRow(title: String, value: Float, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.mutedInk)
                Spacer()
                Text(text)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.04))
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var riskText: String {
        switch audioManager.clippingRisk {
        case 0..<0.35:
            return "LOW"
        case 0.35..<0.72:
            return "WATCH"
        default:
            return "HIGH"
        }
    }

    private var riskColor: Color {
        audioManager.clippingRisk > 0.72 ? theme.accent : (audioManager.clippingRisk > 0.35 ? theme.secondaryAccent : theme.secondaryAccent)
    }

    private func peakColor(_ value: Float) -> Color {
        value > 0.96 ? theme.accent : (value > 0.84 ? theme.secondaryAccent : theme.secondaryAccent)
    }

    private func dbText(_ value: Float) -> String {
        "\(String(format: "%.1f", 20 * log10(max(value, 0.000_001)))) dB"
    }
}
