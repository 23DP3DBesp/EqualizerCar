import SwiftUI

struct EqualizerCurveView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.carAmbientTheme) private var theme

    private let minGain: Float = -24
    private let maxGain: Float = 24
    private let minFreq: Float = 60
    private let maxFreq: Float = 16_000

    var body: some View {
        GeometryReader { geo in
            ZStack {
                seaSpectrumPath(size: geo.size)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.secondaryAccent.opacity(0.05),
                                theme.accent.opacity(0.22)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .animation(.linear(duration: 0.08), value: audioManager.spectrumLevels)

                zeroLine(size: geo.size)

                equalizerFillPath(size: geo.size)
                    .fill(theme.secondaryAccent.opacity(0.08))

                equalizerPath(size: geo.size)
                    .stroke(
                        LinearGradient(colors: [theme.secondaryAccent, theme.secondaryAccent, theme.accent], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                    )

                ForEach(Array(audioManager.bandFrequencies.enumerated()), id: \.offset) { index, _ in
                    let point = position(forIndex: index, size: geo.size)
                    Circle()
                        .fill(theme.surface.opacity(0.96))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(theme.secondaryAccent, lineWidth: 5))
                        .shadow(color: theme.secondaryAccent.opacity(0.28), radius: 10, x: 0, y: 4)
                        .position(point)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    audioManager.setBandGain(index: index, value: gain(forY: value.location.y, height: geo.size.height))
                                }
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .frame(height: 280)
        .padding(12)
        .background(theme.surface.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.accent.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func position(forIndex index: Int, size: CGSize) -> CGPoint {
        guard index < audioManager.bandFrequencies.count,
              index < audioManager.bandGains.count else { return .zero }
        return CGPoint(
            x: xPosition(for: audioManager.bandFrequencies[index], width: size.width),
            y: yPosition(for: audioManager.bandGains[index], height: size.height)
        )
    }

    private func xPosition(for frequency: Float, width: CGFloat) -> CGFloat {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logFrequency = log10(min(max(frequency, minFreq), maxFreq))
        return CGFloat((logFrequency - logMin) / (logMax - logMin)) * width
    }

    private func yPosition(for gain: Float, height: CGFloat) -> CGFloat {
        let ratio = (gain - minGain) / (maxGain - minGain)
        return height * CGFloat(1 - ratio)
    }

    private func gain(forY y: CGFloat, height: CGFloat) -> Float {
        let ratio = 1 - Float(y / max(height, 1))
        return min(max(ratio * (maxGain - minGain) + minGain, minGain), maxGain)
    }

    private func equalizerPath(size: CGSize) -> Path {
        smoothPath(points: (0..<audioManager.bandFrequencies.count).map { position(forIndex: $0, size: size) })
    }

    private func equalizerFillPath(size: CGSize) -> Path {
        var path = equalizerPath(size: size)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func seaSpectrumPath(size: CGSize) -> Path {
        let levels = smoothedSpectrumLevels(audioManager.spectrumLevels)
        guard !levels.isEmpty else { return Path() }
        let points = levels.enumerated().map { index, level in
            let x = size.width * CGFloat(index) / CGFloat(max(levels.count - 1, 1))
            let normalized = CGFloat(min(max(level, 0), 1))
            let swell = sin(CGFloat(index) * 0.38) * 5
            let y = size.height - max(size.height * normalized * 0.78 + swell, 3)
            return CGPoint(x: x, y: y)
        }

        var path = smoothPath(points: points)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func smoothedSpectrumLevels(_ levels: [Float]) -> [Float] {
        guard !levels.isEmpty else { return [] }
        let targetCount = 64
        return (0..<targetCount).map { outputIndex in
            let sourcePosition = Float(outputIndex) * Float(levels.count - 1) / Float(max(targetCount - 1, 1))
            let center = Int(sourcePosition.rounded())
            let range = max(center - 2, 0)...min(center + 2, levels.count - 1)
            let weightedSum = range.reduce(Float(0)) { partial, index in
                let distance = abs(Float(index) - sourcePosition)
                let weight = max(0, 1 - distance / 3)
                return partial + levels[index] * weight
            }
            let weightSum = range.reduce(Float(0)) { partial, index in
                let distance = abs(Float(index) - sourcePosition)
                return partial + max(0, 1 - distance / 3)
            }
            return weightSum > 0 ? weightedSum / weightSum : 0
        }
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midX = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: current.y)
            )
        }
        return path
    }

    private func zeroLine(size: CGSize) -> some View {
        Path { path in
            let zeroY = yPosition(for: 0, height: size.height)
            path.move(to: CGPoint(x: 0, y: zeroY))
            path.addLine(to: CGPoint(x: size.width, y: zeroY))
        }
        .stroke(Color.secondary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
    }
}
