import SwiftUI

struct BassLabView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.carAmbientTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                bassBands
                bassDriveControls
                virtualSubwooferControls
                cabinResonanceControls
                subwooferControls
                dynamicsControls
                protectionControls
                LoudnessMeterView(audioManager: audioManager)
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(theme.screenBackground.ignoresSafeArea())
        .navigationTitle("Bass Lab")
        .onAppear {
            audioManager.prepareBassLab()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Bass Lab", systemImage: "speaker.wave.3.fill")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(audioManager.subwooferModeEnabled ? "SUB" : "CABIN")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(audioManager.subwooferModeEnabled ? theme.secondaryAccent : theme.mutedInk)
            }

            Picker("Smart Mode", selection: Binding(
                get: { audioManager.smartLoudBassMode },
                set: { audioManager.applySmartLoudBassMode($0) }
            )) {
                ForEach(SmartLoudBassMode.allCases) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .liquidGlassPanel(cornerRadius: 14, tint: theme.surface.opacity(0.96))
    }

    private var bassBands: some View {
        panel(title: "Bass Bands", icon: "slider.horizontal.3") {
            bassSlider(title: "Sub Bass", subtitle: "35-60 Hz", value: $audioManager.subBassGain)
            bassSlider(title: "Punch Bass", subtitle: "60-120 Hz", value: $audioManager.punchBassGain)
            bassSlider(title: "Warmth", subtitle: "120-250 Hz", value: $audioManager.warmthGain)
            valueSlider(title: "Bass Tightness", value: $audioManager.bassTightness, range: 0...1, step: 0.05) { "\(Int($0 * 100))%" }
        }
    }

    private var subwooferControls: some View {
        panel(title: "Subwoofer", icon: "car.fill") {
            toggleRow("Subwoofer Mode", icon: "speaker.square.fill", isOn: $audioManager.subwooferModeEnabled)
            toggleRow("Bass Mono below 100 Hz", icon: "circle.lefthalf.filled", isOn: $audioManager.bassMonoBelow100Enabled)
            toggleRow("Phase Invert", icon: "arrow.left.arrow.right", isOn: $audioManager.subwooferPhaseInverted)
            toggleRow("Crossover", icon: "point.3.connected.trianglepath.dotted", isOn: $audioManager.crossoverEnabled)
            valueSlider(title: "Crossover", value: $audioManager.crossoverFrequency, range: 45...200, step: 1) { "\(Int($0)) Hz" }
                .disabled(!audioManager.crossoverEnabled)
            Picker("Mode", selection: $audioManager.crossoverMode) {
                Text("Subwoofer").tag(CrossoverMode.subwoofer)
                Text("Speakers").tag(CrossoverMode.speakers)
            }
            .pickerStyle(.segmented)
            .disabled(!audioManager.crossoverEnabled)
        }
    }

    private var bassDriveControls: some View {
        panel(title: "Bass Drive", icon: "waveform.path") {
            toggleRow("Bass Boost", icon: "speaker.wave.3.fill", isOn: $audioManager.bassBoostEnabled)
            valueSlider(title: "Intensity", value: $audioManager.bassBoostIntensity, range: 0...12, step: 0.5) { String(format: "%.1f dB", $0) }
                .disabled(!audioManager.bassBoostEnabled)
            valueSlider(title: "Center Frequency", value: $audioManager.bassBoostFrequency, range: 35...160, step: 1) { "\(Int($0)) Hz" }
                .disabled(!audioManager.bassBoostEnabled)
            toggleRow("Adaptive Bass", icon: "waveform.path.ecg", isOn: $audioManager.adaptiveBassBoostEnabled)
            Text("Адаптивный режим уменьшает усиление при высоком уровне сигнала.")
                .font(.caption).foregroundStyle(theme.mutedInk)
        }
    }

    private var dynamicsControls: some View {
        panel(title: "Bass Dynamics", icon: "waveform") {
            toggleRow("Compressor", icon: "arrow.down.right.and.arrow.up.left", isOn: $audioManager.compressorEnabled)
            valueSlider(title: "Threshold", value: $audioManager.compressorThreshold, range: -36 ... -6, step: 1) { "\(Int($0)) dB" }
                .disabled(!audioManager.compressorEnabled)
            valueSlider(title: "Ratio", value: $audioManager.compressorRatio, range: 1...10, step: 0.1) { String(format: "%.1f:1", $0) }
                .disabled(!audioManager.compressorEnabled)
            valueSlider(title: "Attack", value: $audioManager.compressorAttack, range: 0.001...0.1, step: 0.001) { "\(Int($0 * 1000)) ms" }
                .disabled(!audioManager.compressorEnabled)
            valueSlider(title: "Release", value: $audioManager.compressorRelease, range: 0.02...0.5, step: 0.01) { "\(Int($0 * 1000)) ms" }
                .disabled(!audioManager.compressorEnabled)
            toggleRow("Multiband Compressor", icon: "slider.vertical.3", isOn: $audioManager.multibandCompressorEnabled)
            toggleRow("Soft Clipper", icon: "waveform.badge.mic", isOn: $audioManager.softClipperEnabled)
        }
    }

    private var protectionControls: some View {
        panel(title: "Bass Protection", icon: "checkmark.shield.fill") {
            toggleRow("Subsonic Filter", icon: "line.3.horizontal.decrease", isOn: $audioManager.subsonicEnabled)
            valueSlider(title: "Cutoff", value: $audioManager.subsonicCutoff, range: 18...60, step: 1) { "\(Int($0)) Hz" }
                .disabled(!audioManager.subsonicEnabled)
            toggleRow("Clip Protection", icon: "shield.lefthalf.filled", isOn: $audioManager.clipperProtectionEnabled)
            toggleRow("Limiter", icon: "speaker.wave.1", isOn: $audioManager.limiterEnabled)
            valueSlider(title: "Ceiling", value: $audioManager.limiterCeiling, range: -12 ... -0.1, step: 0.1) { String(format: "%.1f dB", $0) }
                .disabled(!audioManager.limiterEnabled)
            valueSlider(title: "Release", value: $audioManager.limiterRelease, range: 0.01...0.3, step: 0.01) { "\(Int($0 * 1000)) ms" }
                .disabled(!audioManager.limiterEnabled)
            Text("Subsonic-фильтр убирает инфранизкий сигнал, который расходует запас хода динамика без заметного баса.")
                .font(.caption).foregroundStyle(theme.mutedInk)
        }
    }

    private var virtualSubwooferControls: some View {
        panel(title: "Virtual Subwoofer", icon: "speaker.wave.2.bubble.left.fill") {
            toggleRow("Missing Fundamental", icon: "waveform.path.badge.plus", isOn: $audioManager.virtualSubwooferEnabled)
            valueSlider(title: "Mix", value: $audioManager.virtualSubwooferMix, range: 0...1, step: 0.05) { "\(Int($0 * 100))%" }
                .disabled(!audioManager.virtualSubwooferEnabled)
            valueSlider(title: "Source Cutoff", value: $audioManager.virtualSubwooferCutoff, range: 30...70, step: 1) { "\(Int($0)) Hz" }
                .disabled(!audioManager.virtualSubwooferEnabled)
        }
    }

    private var cabinResonanceControls: some View {
        panel(title: "Cabin Anti-Boom", icon: "waveform.path.ecg") {
            toggleRow("Anti-Boom Notch", icon: "speaker.slash.fill", isOn: $audioManager.cabinNotchEnabled)
            valueSlider(title: "Frequency", value: $audioManager.cabinNotchFrequency, range: 100...200, step: 1) { "\(Int($0)) Hz" }
                .disabled(!audioManager.cabinNotchEnabled)
            valueSlider(title: "Cut", value: $audioManager.cabinNotchGain, range: -18...0, step: 0.5) { "\(String(format: "%.1f", $0)) dB" }
                .disabled(!audioManager.cabinNotchEnabled)
            valueSlider(title: "Q", value: $audioManager.cabinNotchQ, range: 4...8, step: 0.1) { String(format: "%.1f", $0) }
                .disabled(!audioManager.cabinNotchEnabled)
        }
    }

    private func panel<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LocalizedStringKey(title), systemImage: icon)
                .font(.headline)
                .foregroundStyle(theme.ink)
            content()
        }
        .padding(14)
        .background(theme.surface.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.accent.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func bassSlider(title: String, subtitle: String, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.mutedInk)
                }
                Spacer()
                Text("\(String(format: "%.1f", value.wrappedValue)) dB")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(theme.secondaryAccent)
            }
            Slider(value: value, in: -12...12, step: 0.5)
                .tint(theme.secondaryAccent)
        }
    }

    private func valueSlider(title: String, value: Binding<Float>, range: ClosedRange<Float>, step: Float, formatter: @escaping (Float) -> String) -> some View {
        HStack(spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.mutedInk)
                .frame(width: 112, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .tint(theme.secondaryAccent)
            Text(formatter(value.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.ink)
                .frame(width: 64, alignment: .trailing)
        }
    }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(LocalizedStringKey(title), systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
        }
        .toggleStyle(.switch)
        .tint(theme.secondaryAccent)
    }
}

#Preview {
    NavigationStack {
        BassLabView(audioManager: AudioEngineManager())
    }
}
