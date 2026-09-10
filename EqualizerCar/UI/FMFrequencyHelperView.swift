import SwiftUI

struct FMFrequencyHelperView: View {
    @Environment(\.carAmbientTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("FM Frequency Helper", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
                .foregroundStyle(theme.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(FMFrequencyCandidate.localCleanCandidates) { candidate in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: "%.1f MHz", candidate.frequencyMHz))
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(theme.secondaryAccent)
                        Text(candidate.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.ink)
                        Text(candidate.note)
                            .font(.caption2)
                            .foregroundStyle(theme.mutedInk)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(14)
        .liquidGlassPanel(cornerRadius: 12, tint: theme.surface.opacity(theme.glassOpacity))
    }
}

#Preview {
    FMFrequencyHelperView()
        .preferredColorScheme(.light)
}
