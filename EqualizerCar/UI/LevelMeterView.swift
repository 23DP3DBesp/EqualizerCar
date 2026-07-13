//
//  LevelMeterView.swift
//  EqualizerCar
//
//  Created by Денис Беспалов on 08/07/2026.
//

import SwiftUI

/// Простой real-time индикатор громкости (RMS level meter).
/// Это НЕ полноценный spectrum analyzer (частотный анализ) — тот
/// потребует FFT через Accelerate framework, добавим отдельным шагом.
/// Это первая, простая версия визуализации звука.
struct LevelMeterView: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .green, .yellow, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: barWidth(totalWidth: geo.size.width))
                    // Плавная анимация — иначе метр будет дёргаться резко
                    // при каждом обновлении буфера.
                    .animation(.linear(duration: 0.05), value: level)
            }
        }
        .frame(height: 8)
    }

    private func barWidth(totalWidth: CGFloat) -> CGFloat {
        // RMS обычно в диапазоне 0...1, но редко приближается к 1 —
        // умножаем для более отзывчивой визуальной шкалы.
        let normalized = min(CGFloat(level) * 4, 1.0)
        return totalWidth * normalized
    }
}
