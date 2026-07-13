import SwiftUI

struct WaveformProgressView: View {
    let samples: [Float]
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let barCount = max(samples.count, 1)
            let spacing: CGFloat = 2
            let totalSpacing = spacing * CGFloat(max(barCount - 1, 0))
            let barWidth = max((geometry.size.width - totalSpacing) / CGFloat(barCount), 1.5)
            let progressX = geometry.size.width * min(max(CGFloat(progress), 0), 1)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    let x = CGFloat(index) * (barWidth + spacing)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(x <= progressX ? Color.cyan : Color.secondary.opacity(0.28))
                        .frame(
                            width: barWidth,
                            height: barHeight(sample: sample, availableHeight: geometry.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 42)
        .accessibilityHidden(true)
    }

    private func barHeight(sample: Float, availableHeight: CGFloat) -> CGFloat {
        let normalized = min(max(CGFloat(sample), 0), 1)
        return max(availableHeight * normalized, 3)
    }
}

#Preview {
    WaveformProgressView(
        samples: (0..<160).map { abs(sin(Float($0) * 0.18)) },
        progress: 0.42
    )
    .padding()
    .preferredColorScheme(.dark)
}
