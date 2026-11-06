import SwiftUI

struct EqualizerCurveView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.carAmbientTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    for fraction in [0.0, 0.5, 1.0] {
                        let y = geometry.size.height * fraction
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
                        let x = geometry.size.width * fraction
                        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                }.stroke(theme.separator, style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                EQBandCurve(gains: EQGains(values: audioManager.bandGains.map(Double.init)), frequencies: audioManager.bandFrequencies, fill: true)
                    .fill(LinearGradient(colors: [theme.accent.opacity(0.12), theme.accent.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: audioManager.bandGains)
                EQBandCurve(gains: EQGains(values: audioManager.bandGains.map(Double.init)), frequencies: audioManager.bandFrequencies)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: audioManager.bandGains)
                ForEach(Array(audioManager.bandFrequencies.enumerated()), id: \.offset) { index, frequency in
                    let gain = audioManager.bandGains.indices.contains(index) ? audioManager.bandGains[index] : 0
                    Circle().fill(theme.accent).frame(width: 6, height: 6)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                        .position(x: CGFloat(log10(frequency / 35) / log10(16000 / Float(35))) * geometry.size.width,
                                  y: CGFloat((24 - gain) / 48) * geometry.size.height)
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("EQChart")).onChanged { gesture in
                            let value = 24 - Float(gesture.location.y / max(geometry.size.height, 1)) * 48
                            audioManager.setBandGain(index: index, value: min(max(value, -24), 24))
                        })
                }
            }.coordinateSpace(name: "EQChart")
        }.frame(height: 136).padding(.horizontal, 4)
            .opacity(audioManager.isEqualizerEnabled ? 1 : 0.35).disabled(!audioManager.isEqualizerEnabled)
            .accessibilityLabel("Equalizer curve; adjust individual bands below")
    }
}

private struct EQGains: VectorArithmetic {
    var values: [Double]
    static var zero: EQGains { EQGains(values: []) }
    static func + (lhs: EQGains, rhs: EQGains) -> EQGains { combine(lhs, rhs, sign: 1) }
    static func - (lhs: EQGains, rhs: EQGains) -> EQGains { combine(lhs, rhs, sign: -1) }
    private static func combine(_ lhs: EQGains, _ rhs: EQGains, sign: Double) -> EQGains {
        EQGains(values: (0..<max(lhs.values.count, rhs.values.count)).map {
            (lhs.values.indices.contains($0) ? lhs.values[$0] : 0) + sign * (rhs.values.indices.contains($0) ? rhs.values[$0] : 0)
        })
    }
    mutating func scale(by rhs: Double) { values = values.map { $0 * rhs } }
    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }
}

private struct EQBandCurve: Shape {
    var gains: EQGains
    let frequencies: [Float]
    var fill = false
    var animatableData: EQGains { get { gains } set { gains = newValue } }
    func path(in rect: CGRect) -> Path {
        let points = frequencies.enumerated().map { index, frequency in
            CGPoint(x: CGFloat(log10(frequency / 35) / log10(16000 / Float(35))) * rect.width,
                    y: (24 - (gains.values.indices.contains(index) ? gains.values[index] : 0)) / 48 * rect.height)
        }
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1], next = points[index], middle = (previous.x + next.x) / 2
            path.addCurve(to: next, control1: CGPoint(x: middle, y: previous.y), control2: CGPoint(x: middle, y: next.y))
        }
        if fill {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); path.closeSubpath()
        }
        return path
    }
}
