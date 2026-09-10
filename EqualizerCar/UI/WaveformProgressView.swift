import SwiftUI

struct WaveformProgressView: View {
    @Environment(\.carAmbientTheme) private var theme
    let samples: [Float]
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let progressWidth = geometry.size.width * min(max(CGFloat(progress), 0), 1)
            let shape = SmoothWaveformShape(samples: displaySamples)

            ZStack(alignment: .leading) {
                shape
                    .fill(Color.black.opacity(0.04))

                shape
                    .fill(
                        LinearGradient(
                            colors: [theme.secondaryAccent, theme.secondaryAccent, theme.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: progressWidth)
                    }

                Capsule()
                    .fill(theme.secondaryAccent)
                    .frame(width: 3)
                    .shadow(color: theme.secondaryAccent.opacity(0.55), radius: 8, x: 0, y: 0)
                    .offset(x: max(progressWidth - 1.5, 0))
                    .opacity(progress > 0 ? 1 : 0)
            }
            .animation(.smooth(duration: 0.22), value: progress)
        }
        .frame(height: 48)
        .accessibilityHidden(true)
    }

    private var displaySamples: [Float] {
        let source = samples.isEmpty ? (0..<96).map { index in
            Float(0.18 + abs(sin(Double(index) * 0.11)) * 0.08)
        } : samples

        return smoothed(source, targetCount: 180)
    }

    private func smoothed(_ source: [Float], targetCount: Int) -> [Float] {
        guard !source.isEmpty else { return [] }

        return (0..<targetCount).map { outputIndex in
            let position = Float(outputIndex) * Float(source.count - 1) / Float(max(targetCount - 1, 1))
            let center = Int(position.rounded())
            let lowerBound = max(center - 3, 0)
            let upperBound = min(center + 3, source.count - 1)
            var weightedSum: Float = 0
            var weightSum: Float = 0

            for index in lowerBound...upperBound {
                let distance = abs(Float(index) - position)
                let weight = max(0, 1 - distance / 4)
                weightedSum += max(source[index], 0.02) * weight
                weightSum += weight
            }

            return min(max(weightedSum / max(weightSum, 0.001), 0.03), 1)
        }
    }
}

private struct SmoothWaveformShape: Shape {
    let samples: [Float]

    func path(in rect: CGRect) -> Path {
        guard samples.count > 1 else { return Path() }

        let midY = rect.midY
        let maxAmplitude = rect.height * 0.46
        let topPoints = samples.enumerated().map { index, sample in
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(max(samples.count - 1, 1))
            let amplitude = maxAmplitude * CGFloat(min(max(sample, 0), 1))
            return CGPoint(x: x, y: midY - max(amplitude, 2))
        }
        let bottomPoints = samples.enumerated().reversed().map { index, sample in
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(max(samples.count - 1, 1))
            let amplitude = maxAmplitude * CGFloat(min(max(sample, 0), 1))
            return CGPoint(x: x, y: midY + max(amplitude, 2))
        }

        var path = smoothLine(points: topPoints)
        path.addLine(to: bottomPoints[0])
        path.addPath(smoothLine(points: bottomPoints, startsNewSubpath: false))
        path.closeSubpath()
        return path
    }

    private func smoothLine(points: [CGPoint], startsNewSubpath: Bool = true) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        if startsNewSubpath {
            path.move(to: first)
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: mid, control: previous)
            path.addQuadCurve(to: current, control: mid)
        }

        return path
    }
}

#Preview {
    WaveformProgressView(
        samples: (0..<160).map { abs(sin(Float($0) * 0.18)) },
        progress: 0.42
    )
    .padding()
    .preferredColorScheme(.light)
}
