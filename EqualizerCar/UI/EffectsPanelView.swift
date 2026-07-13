import SwiftUI

struct EffectsPanelView: View {
    @ObservedObject var audioManager: AudioEngineManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Эффекты")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Toggle("Safe Loud Mode", isOn: $audioManager.safeLoudModeEnabled)
                    .toggleStyle(.button)

                Spacer()

                Button(role: .destructive) {
                    audioManager.resetAllEffects()
                } label: {
                    Label("Reset all effects", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }

            effectGroup("Tone") {
                Toggle("Bass Boost", isOn: $audioManager.bassBoostEnabled)
                Toggle("Treble Boost", isOn: $audioManager.trebleBoostEnabled)
                Toggle("Loudness", isOn: $audioManager.loudnessEnabled)
            }

            effectGroup("Gain Staging") {
                valueSlider(title: "Input", value: $audioManager.inputGain, range: 0...1.25, step: 0.01, formatter: percentText)
                valueSlider(title: "Output", value: $audioManager.outputGain, range: 0...1.25, step: 0.01, formatter: percentText)
                valueSlider(
                    title: "Volume Boost",
                    value: Binding(
                        get: { audioManager.volumeBoost },
                        set: { audioManager.setVolumeBoost($0) }
                    ),
                    range: 1...3,
                    step: 0.05,
                    formatter: percentText
                )
            }

            effectGroup("Dynamics") {
                Toggle("Compressor", isOn: $audioManager.compressorEnabled)
                valueSlider(title: "Threshold", value: $audioManager.compressorThreshold, range: -60...0, step: 1, formatter: dbText)
                    .disabled(!audioManager.compressorEnabled)
                valueSlider(title: "Ratio", value: $audioManager.compressorRatio, range: 1...20, step: 0.5) { "\(String(format: "%.1f", $0)):1" }
                    .disabled(!audioManager.compressorEnabled)
                valueSlider(title: "Attack", value: $audioManager.compressorAttack, range: 0.001...0.100, step: 0.001, formatter: secondsText)
                    .disabled(!audioManager.compressorEnabled)
                valueSlider(title: "Release", value: $audioManager.compressorRelease, range: 0.020...1.000, step: 0.01, formatter: secondsText)
                    .disabled(!audioManager.compressorEnabled)

                Toggle("Limiter", isOn: $audioManager.limiterEnabled)
                valueSlider(title: "Ceiling", value: $audioManager.limiterCeiling, range: -12...0, step: 0.5, formatter: dbText)
                    .disabled(!audioManager.limiterEnabled)
                valueSlider(title: "Limiter Release", value: $audioManager.limiterRelease, range: 0.010...0.500, step: 0.01, formatter: secondsText)
                    .disabled(!audioManager.limiterEnabled)

                Toggle("Soft Clipper", isOn: $audioManager.softClipperEnabled)
            }

            effectGroup("Space") {
                effectSlider(title: "Stereo Widening", isEnabled: $audioManager.stereoWideningEnabled, value: $audioManager.stereoWideningIntensity)
                effectSlider(title: "Spatial Audio", isEnabled: $audioManager.spatialAudioEnabled, value: $audioManager.spatialAudioDepth)
                effectSlider(title: "Surround", isEnabled: $audioManager.surroundEnabled, value: $audioManager.surroundAmount)
                Toggle("8D Audio", isOn: $audioManager.eightDAudioEnabled)
                valueSlider(title: "8D Intensity", value: $audioManager.eightDAudioIntensity, range: 0...1, step: 0.05, formatter: percentText)
                    .disabled(!audioManager.eightDAudioEnabled)
                valueSlider(title: "8D Speed", value: $audioManager.eightDAudioSpeed, range: 0.03...0.75, step: 0.01) { "\(String(format: "%.2f", $0))x" }
                    .disabled(!audioManager.eightDAudioEnabled)

                valueSlider(title: "Reverb Mix", value: $audioManager.reverbAmount, range: 0...100, step: 1) { "\(Int($0))%" }
                valueSlider(title: "Reverb Size", value: $audioManager.reverbSize, range: 0...1, step: 0.05, formatter: percentText)
                valueSlider(title: "Damping", value: $audioManager.reverbDamping, range: 0...1, step: 0.05, formatter: percentText)
            }
        }
        .padding(.horizontal)
    }

    private func effectGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func effectSlider(title: String, isEnabled: Binding<Bool>, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: isEnabled)
            valueSlider(title: "Amount", value: value, range: 0...1, step: 0.05, formatter: percentText)
                .disabled(!isEnabled.wrappedValue)
        }
    }

    private func valueSlider(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        step: Float,
        formatter: @escaping (Float) -> String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            Slider(value: value, in: range, step: step)

            Text(formatter(value.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)
        }
    }

    private func percentText(_ value: Float) -> String {
        "\(Int(value * 100))%"
    }

    private func dbText(_ value: Float) -> String {
        "\(String(format: "%.1f", value)) dB"
    }

    private func secondsText(_ value: Float) -> String {
        value < 1 ? "\(Int(value * 1_000)) ms" : "\(String(format: "%.2f", value)) s"
    }
}
