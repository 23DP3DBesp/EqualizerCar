import SwiftUI

struct EqualizerTabView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.carAmbientTheme) private var theme
    var isEmbedded = false

    var body: some View {
        Group {
            if isEmbedded {
                content
            } else {
                ScrollView {
                    content
                        .padding(20)
                        .padding(.bottom, 96)
                }
                .background(theme.screenBackground.ignoresSafeArea())
                .navigationTitle("Equalizer")
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EQ CONSOLE")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(theme.ink)
                    Text("\(audioManager.bandCount) active bands")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.mutedInk)
                }

                Spacer()

                Picker("Bands", selection: Binding(
                    get: { audioManager.bandCount },
                    set: { audioManager.setBandCount($0) }
                )) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("20").tag(20)
                }
                .pickerStyle(.segmented)
                .frame(width: 168)
            }
            .padding(14)
            .liquidGlassPanel(cornerRadius: 14, tint: theme.surface.opacity(0.96))

            EqualizerCurveView(audioManager: audioManager)

            VStack(spacing: 8) {
                ForEach(Array(audioManager.bandFrequencies.enumerated()), id: \.offset) { index, frequency in
                    HStack(spacing: 12) {
                        Text(frequencyLabel(frequency))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.mutedInk)
                            .frame(width: 54, alignment: .leading)

                        Slider(
                            value: Binding(
                                get: { audioManager.bandGains.indices.contains(index) ? audioManager.bandGains[index] : 0 },
                                set: { audioManager.setBandGain(index: index, value: $0) }
                            ),
                            in: -24...24,
                            step: 0.5
                        )
                        .tint(theme.secondaryAccent)

                        Text("\(Int(audioManager.bandGains.indices.contains(index) ? audioManager.bandGains[index] : 0)) dB")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.ink)
                            .frame(width: 50, alignment: .trailing)

                        filterTypeMenu(index: index)
                    }
                    .padding(10)
                    .background(theme.surface.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.accent.opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func filterTypeMenu(index: Int) -> some View {
        Menu {
            ForEach(EQBandFilterType.allCases) { type in
                Button {
                    audioManager.setBandFilterType(index: index, type: type)
                } label: {
                    Label(type.rawValue, systemImage: type.systemImage)
                }
            }
        } label: {
            Image(systemName: audioManager.bandFilterTypes.indices.contains(index) ? audioManager.bandFilterTypes[index].systemImage : EQBandFilterType.parametric.systemImage)
                .foregroundStyle(theme.secondaryAccent)
                .frame(width: 30, height: 30)
        }
    }

    private func frequencyLabel(_ frequency: Float) -> String {
        frequency >= 1_000 ? "\(Int(frequency / 1_000))k" : "\(Int(frequency))"
    }
}
