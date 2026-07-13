//
//  EqualizerCurveView.swift
//  EqualizerCar
//
//  Created by Денис Беспалов on 08/07/2026.
//

import SwiftUI

/// Интерактивная кривая эквалайзера — как в Airs Audio / Boom3D:
/// каждая полоса представлена точкой на кривой, точку можно
/// перетаскивать пальцем/мышью вертикально, чтобы менять gain
/// в реальном времени во время проигрывания.
struct EqualizerCurveView: View {
    @ObservedObject var audioManager: AudioEngineManager

    private let minGain: Float = -24
    private let maxGain: Float = 24
    private let minFreq: Float = 60
    private let maxFreq: Float = 16000

    var body: some View {
        GeometryReader { geo in
            ZStack {
                zeroLine(size: geo.size)
                curvePath(size: geo.size)
                    .stroke(Color.blue, lineWidth: 2)

                ForEach(Array(audioManager.bandFrequencies.enumerated()), id: \.offset) { index, _ in
                    let point = position(forIndex: index, size: geo.size)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 18, height: 18)
                        .position(point)
                        // minimumDistance: 0 — точка реагирует сразу на касание,
                        // без необходимости "сдвинуть" палец перед началом драга.
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let newGain = gain(forY: value.location.y, height: geo.size.height)
                                    audioManager.setBandGain(index: index, value: newGain)
                                }
                        )
                }
            }
        }
        .frame(height: 220)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Позиционирование точек

    private func position(forIndex index: Int, size: CGSize) -> CGPoint {
        guard index < audioManager.bandFrequencies.count,
              index < audioManager.bandGains.count else { return .zero }
        let x = xPosition(for: audioManager.bandFrequencies[index], width: size.width)
        let y = yPosition(for: audioManager.bandGains[index], height: size.height)
        return CGPoint(x: x, y: y)
    }

    // Частота -> X координата, в логарифмической шкале (как человеческий слух).
    private func xPosition(for frequency: Float, width: CGFloat) -> CGFloat {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logF = log10(max(frequency, minFreq))
        let ratio = (logF - logMin) / (logMax - logMin)
        return CGFloat(ratio) * width
    }

    // Gain (dB) -> Y координата. Инвертируем, т.к. в SwiftUI Y растёт вниз.
    private func yPosition(for gain: Float, height: CGFloat) -> CGFloat {
        let ratio = (gain - minGain) / (maxGain - minGain)
        return height * CGFloat(1 - ratio)
    }

    // Y координата пальца -> Gain (dB). Обратное преобразование для drag-жеста.
    private func gain(forY y: CGFloat, height: CGFloat) -> Float {
        let ratio = 1 - (y / height)
        let value = Float(ratio) * (maxGain - minGain) + minGain
        return min(max(value, minGain), maxGain)
    }

    // MARK: - Отрисовка

    /// Рисуем плавную кривую через все точки полос (сглаженная via Bezier),
    /// это то, что визуально отличает "профессиональный" EQ от простых слайдеров.
    private func curvePath(size: CGSize) -> Path {
        var path = Path()
        let points = (0..<audioManager.bandFrequencies.count).map { position(forIndex: $0, size: size) }
        guard let first = points.first else { return path }

        path.move(to: first)
        guard points.count > 1 else { return path }

        for i in 1..<points.count {
            let previous = points[i - 1]
            let current = points[i]
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
        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }
}
