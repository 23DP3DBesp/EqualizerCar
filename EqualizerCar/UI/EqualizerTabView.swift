import SwiftUI

struct EqualizerTabView: View {
    @ObservedObject var audioManager: AudioEngineManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Bands", selection: Binding(
                    get: { audioManager.bandCount },
                    set: { audioManager.setBandCount($0) }
                )) {
                    Text("5 band").tag(5)
                    Text("10 band").tag(10)
                    Text("20 band").tag(20)
                }
                .pickerStyle(.segmented)

                EqualizerCurveView(audioManager: audioManager)

                VStack(spacing: 10) {
                    ForEach(Array(audioManager.bandFrequencies.enumerated()), id: \.offset) { index, frequency in
                        HStack(spacing: 12) {
                            Text(frequencyLabel(frequency))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 54, alignment: .leading)

                            Slider(
                                value: Binding(
                                    get: { audioManager.bandGains.indices.contains(index) ? audioManager.bandGains[index] : 0 },
                                    set: { audioManager.setBandGain(index: index, value: $0) }
                                ),
                                in: -24...24,
                                step: 0.5
                            )

                            Text("\(Int(audioManager.bandGains.indices.contains(index) ? audioManager.bandGains[index] : 0)) dB")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Equalizer")
    }

    private func frequencyLabel(_ frequency: Float) -> String {
        frequency >= 1_000 ? "\(Int(frequency / 1_000))k" : "\(Int(frequency))"
    }
}
