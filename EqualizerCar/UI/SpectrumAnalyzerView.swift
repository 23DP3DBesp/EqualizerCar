import SwiftUI

struct SpectrumAnalyzerView: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { geometry in
            let barCount = max(levels.count, 1)
            let spacing: CGFloat = 3
            let totalSpacing = spacing * CGFloat(max(barCount - 1, 0))
            let barWidth = max((geometry.size.width - totalSpacing) / CGFloat(barCount), 2)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barGradient)
                        .frame(
                            width: barWidth,
                            height: barHeight(level: level, availableHeight: geometry.size.height)
                        )
                        .animation(.linear(duration: 0.06), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 64)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [Color.cyan, Color.blue, Color.pink],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func barHeight(level: Float, availableHeight: CGFloat) -> CGFloat {
        let normalized = min(max(CGFloat(level), 0), 1)
        return max(availableHeight * normalized, 2)
    }
}

#Preview {
    SpectrumAnalyzerView(levels: (0..<24).map { Float($0) / 23 })
        .padding()
        .preferredColorScheme(.dark)
}
