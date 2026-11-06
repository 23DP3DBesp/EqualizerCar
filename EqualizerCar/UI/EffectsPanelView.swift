import SwiftUI

struct EffectsPanelView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.carAmbientTheme) private var theme
    @State private var lastReverbMix: Float = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            rackHeader
            newEffectsModule
            smartChainModule
            legacyCarModule
            LoudnessMeterView(audioManager: audioManager)

            rackModule(title: "Tone Shaper", icon: "slider.horizontal.3", isActive: audioManager.bassBoostEnabled || audioManager.trebleBoostEnabled || audioManager.loudnessEnabled) {
                toggleRow("Bass Boost", icon: "speaker.wave.3.fill", isOn: $audioManager.bassBoostEnabled)
                if audioManager.bassBoostEnabled {
                    valueSlider(title: "Intensity", value: $audioManager.bassBoostIntensity, range: 0...12, step: 0.5, formatter: dbText)
                    valueSlider(title: "Frequency", value: $audioManager.bassBoostFrequency, range: 40...150, step: 1) { "\(Int($0)) Hz" }
                    toggleRow("Adaptive Bass", icon: "waveform.path", isOn: $audioManager.adaptiveBassBoostEnabled)
                }

                toggleRow("Treble Boost", icon: "hifispeaker.2.fill", isOn: $audioManager.trebleBoostEnabled)
                toggleRow("Loudness", icon: "speaker.plus.fill", isOn: $audioManager.loudnessEnabled)
                valueSlider(title: "Balance", value: $audioManager.stereoBalance, range: -1...1, step: 0.01) { "\(Int(($0 + 1) * 50))%" }
                Text("Front/rear fader requires separate rear output channels; this player processes stereo.")
                    .font(.caption).foregroundStyle(theme.mutedInk)
            }

            rackModule(title: "Gain Stage", icon: "gauge.with.dots.needle.67percent", isActive: audioManager.inputGain != 1 || audioManager.outputGain != 1 || audioManager.volumeBoost != 1) {
                valueSlider(title: "Input", value: $audioManager.inputGain, range: 0...1.25, step: 0.01, formatter: percentText)
                valueSlider(title: "Output", value: $audioManager.outputGain, range: 0...1.25, step: 0.01, formatter: percentText)
                valueSlider(
                    title: "Boost",
                    value: Binding(
                        get: { audioManager.volumeBoost },
                        set: { audioManager.setVolumeBoost($0) }
                    ),
                    range: 1...3,
                    step: 0.05,
                    formatter: percentText
                )
            }

            rackModule(title: "Dynamics Processor", icon: "waveform.path.ecg", isActive: audioManager.compressorEnabled || audioManager.limiterEnabled || audioManager.softClipperEnabled || audioManager.multibandCompressorEnabled) {
                toggleRow("Safe Loud Mode", icon: "shield.fill", isOn: $audioManager.safeLoudModeEnabled)
                toggleRow("Multiband", icon: "waveform.path.ecg.rectangle", isOn: $audioManager.multibandCompressorEnabled)
                toggleRow("Compressor", icon: "arrow.down.forward.and.arrow.up.backward", isOn: $audioManager.compressorEnabled)
                valueSlider(title: "Threshold", value: $audioManager.compressorThreshold, range: -60...0, step: 1, formatter: dbText)
                    .disabled(!audioManager.compressorEnabled)
                valueSlider(title: "Ratio", value: $audioManager.compressorRatio, range: 1...20, step: 0.5) { "\(String(format: "%.1f", $0)):1" }
                    .disabled(!audioManager.compressorEnabled)
                valueSlider(title: "Attack", value: $audioManager.compressorAttack, range: 0.001...0.100, step: 0.001, formatter: secondsText)
                    .disabled(!audioManager.compressorEnabled)
                valueSlider(title: "Release", value: $audioManager.compressorRelease, range: 0.020...1.000, step: 0.01, formatter: secondsText)
                    .disabled(!audioManager.compressorEnabled)

                Divider().overlay(theme.accent.opacity(0.18))

                toggleRow("Limiter", icon: "waveform.badge.exclamationmark", isOn: $audioManager.limiterEnabled)
                valueSlider(title: "Ceiling", value: $audioManager.limiterCeiling, range: -12...0, step: 0.5, formatter: dbText)
                    .disabled(!audioManager.limiterEnabled)
                valueSlider(title: "Release", value: $audioManager.limiterRelease, range: 0.010...0.500, step: 0.01, formatter: secondsText)
                    .disabled(!audioManager.limiterEnabled)
                toggleRow("Soft Clipper", icon: "scissors", isOn: $audioManager.softClipperEnabled)
                valueSlider(title: "Clip Drive", value: $audioManager.softClipperDrive, range: 0...1, step: 0.01, formatter: percentText)
                    .disabled(!audioManager.softClipperEnabled)
            }

            rackModule(title: "Cabin Space", icon: "car.fill", isActive: audioManager.crossoverEnabled || audioManager.stereoWideningEnabled || audioManager.spatialAudioEnabled || audioManager.surroundEnabled || audioManager.eightDAudioEnabled) {
                toggleRow("Crossover", icon: "point.3.connected.trianglepath.dotted", isOn: $audioManager.crossoverEnabled)
                if audioManager.crossoverEnabled {
                    valueSlider(title: "Frequency", value: $audioManager.crossoverFrequency, range: 60...200, step: 1) { "\(Int($0)) Hz" }
                    Picker("Mode", selection: $audioManager.crossoverMode) {
                        Text("Subwoofer").tag(CrossoverMode.subwoofer)
                        Text("Speakers").tag(CrossoverMode.speakers)
                    }
                    .pickerStyle(.segmented)
                toggleRow("Invert Sub Phase", icon: "arrow.left.arrow.right", isOn: $audioManager.subwooferPhaseInverted)
                    Text("Polarity inversion alone usually sounds unchanged; use it to align a separate subwoofer.")
                        .font(.caption).foregroundStyle(theme.mutedInk)
                }

                effectSlider(title: "Stereo Width", icon: "arrow.left.and.right", isEnabled: $audioManager.stereoWideningEnabled, value: $audioManager.stereoWideningIntensity)
                Text("Width needs stereo material. Spatial Depth and Stereo 3D also add width to mono; stereo speakers or headphones are needed to hear it.")
                    .font(.caption).foregroundStyle(theme.mutedInk)
                effectSlider(title: "Spatial Depth", icon: "circle.hexagongrid.fill", isEnabled: $audioManager.spatialAudioEnabled, value: $audioManager.spatialAudioDepth)
                effectSlider(title: "Surround", icon: "dot.radiowaves.left.and.right", isEnabled: $audioManager.surroundEnabled, value: $audioManager.surroundAmount)

                toggleRow("8D Audio", icon: "rotate.3d", isOn: $audioManager.eightDAudioEnabled)
                Picker("8D Mode", selection: $audioManager.eightDAudioMode) {
                    ForEach(EightDAudioMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!audioManager.eightDAudioEnabled)
                eightDMotionView
                valueSlider(title: "8D Intensity", value: $audioManager.eightDAudioIntensity, range: 0...1, step: 0.05, formatter: percentText)
                    .disabled(!audioManager.eightDAudioEnabled)
                valueSlider(title: "8D Speed", value: $audioManager.eightDAudioSpeed, range: 0.03...0.75, step: 0.01) { "\(String(format: "%.2f", $0)) Hz" }
                    .disabled(!audioManager.eightDAudioEnabled)

                Divider().overlay(theme.accent.opacity(0.18))

                toggleRow("Reverb", icon: "waveform", isOn: Binding(
                    get: { audioManager.reverbAmount > 0 },
                    set: { enabled in
                        if enabled {
                            audioManager.reverbAmount = lastReverbMix
                        } else {
                            lastReverbMix = max(audioManager.reverbAmount, 1)
                            audioManager.reverbAmount = 0
                        }
                    }
                ))
                valueSlider(title: "Reverb Mix", value: $audioManager.reverbAmount, range: 0...100, step: 1) { "\(Int($0))%" }
                valueSlider(title: "Room Size", value: $audioManager.reverbSize, range: 0...1, step: 0.05, formatter: percentText)
                valueSlider(title: "Damping", value: $audioManager.reverbDamping, range: 0...1, step: 0.05, formatter: percentText)
            }
        }
    }

    private var newEffectsModule: some View {
        VStack(spacing: 14) {
            rackModule(title: "Subsonic Filter", icon: "waveform", isActive: audioManager.subsonicEnabled) {
                toggleRow("Enable Subsonic Filter", icon: "waveform", isOn: $audioManager.subsonicEnabled)
                Text("Cuts deep rumble below the selected frequency (24 dB/octave).").font(.caption).foregroundStyle(theme.mutedInk)
                valueSlider(title: "Cutoff", value: $audioManager.subsonicCutoff, range: 20...60, step: 1) { "\(Int($0)) Hz" }
                    .disabled(!audioManager.subsonicEnabled)
            }
            rackModule(title: "Vocal Clarity", icon: "waveform", isActive: audioManager.vocalClarityEnabled) {
                toggleRow("Enable Vocal Clarity", icon: "waveform", isOn: $audioManager.vocalClarityEnabled)
                Text("Reduces low-mid muddiness and emphasizes vocal presence.").font(.caption).foregroundStyle(theme.mutedInk)
                valueSlider(title: "Amount", value: $audioManager.vocalClarityAmount, range: 0...1, step: 0.01, formatter: percentText)
                    .disabled(!audioManager.vocalClarityEnabled)
            }
            rackModule(title: "Night Mode", icon: "waveform", isActive: audioManager.nightModeEnabled) {
                toggleRow("Enable Night Mode", icon: "waveform", isOn: $audioManager.nightModeEnabled)
                Text("Compresses loud passages with gentle makeup gain for quieter listening.").font(.caption).foregroundStyle(theme.mutedInk)
                valueSlider(title: "Amount", value: $audioManager.nightModeAmount, range: 0...1, step: 0.01, formatter: percentText)
                    .disabled(!audioManager.nightModeEnabled)
            }
            rackModule(title: "Parametric Notch", icon: "waveform.path.ecg", isActive: audioManager.parametricNotchEnabled) {
                toggleRow("Enable Notch", icon: "line.3.horizontal.decrease", isOn: $audioManager.parametricNotchEnabled)
                Text("Reduce a specific resonance without cutting the entire frequency range.")
                    .font(.caption).foregroundStyle(theme.mutedInk)
                // A logarithmic scale gives the low-frequency range usable precision.
                valueSlider(title: "Frequency", value: Binding(
                    get: { log10(audioManager.parametricNotchFrequency) },
                    set: { audioManager.parametricNotchFrequency = pow(10, $0) }
                ), range: log10(20)...log10(20_000), step: 0.005) { "\(Int(pow(10, $0))) Hz" }
                    .disabled(!audioManager.parametricNotchEnabled)
                valueSlider(title: "Q", value: $audioManager.parametricNotchQ, range: 0.3...20, step: 0.1) { String(format: "%.1f", $0) }
                    .disabled(!audioManager.parametricNotchEnabled)
                valueSlider(title: "Cut", value: $audioManager.parametricNotchDepth, range: -36...0, step: 0.5, formatter: dbText)
                    .disabled(!audioManager.parametricNotchEnabled)
            }
            rackModule(title: "Tape Saturation", icon: "waveform", isActive: audioManager.tapeSaturationEnabled) {
                toggleRow("Enable Saturation", icon: "waveform", isOn: $audioManager.tapeSaturationEnabled)
                Text("Tape-style soft saturation. Drive adds harmonics; Mix blends the original signal.")
                    .font(.caption).foregroundStyle(theme.mutedInk)
                valueSlider(title: "Drive", value: $audioManager.tapeSaturationDrive, range: 0...1, step: 0.01, formatter: percentText)
                    .disabled(!audioManager.tapeSaturationEnabled)
                valueSlider(title: "Mix", value: $audioManager.tapeSaturationMix, range: 0...1, step: 0.01, formatter: percentText)
                    .disabled(!audioManager.tapeSaturationEnabled)
            }
            rackModule(title: "Transient Shaper", icon: "waveform.path", isActive: audioManager.transientShaperEnabled) {
                toggleRow("Enable Transients", icon: "waveform.path", isOn: $audioManager.transientShaperEnabled)
                Text("Shape drum attack and sustain. Positive values emphasize; negative values soften.")
                    .font(.caption).foregroundStyle(theme.mutedInk)
                valueSlider(title: "Attack", value: $audioManager.transientAttack, range: -12...12, step: 0.5, formatter: dbText)
                    .disabled(!audioManager.transientShaperEnabled)
                valueSlider(title: "Sustain", value: $audioManager.transientSustain, range: -12...12, step: 0.5, formatter: dbText)
                    .disabled(!audioManager.transientShaperEnabled)
            }
        }
    }

    private var rackHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DSP RACK")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text("Signal chain modules")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.mutedInk)
            }

            Spacer()

            Button(role: .destructive) {
                audioManager.resetAllEffects()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .liquidGlassPanel(cornerRadius: 14, tint: theme.surface.opacity(0.96))
    }

    private var smartChainModule: some View {
        rackModule(title: "Smart Loud Bass Chain", icon: "bolt.circle.fill", isActive: audioManager.smartLoudBassMode != .clean) {
            Picker("Mode", selection: Binding(
                get: { audioManager.smartLoudBassMode },
                set: { audioManager.applySmartLoudBassMode($0) }
            )) {
                ForEach(SmartLoudBassMode.allCases) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                ForEach(["Input", "Dynamic EQ", "Bass", "Multiband", "Clip", "Width", "Limiter", "Output"], id: \.self) { item in
                    Text(LocalizedStringKey(item))
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(theme.surface.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(theme.accent.opacity(0.18), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }

            toggleRow("Headroom Guard", icon: "shield.lefthalf.filled", isOn: $audioManager.safeLoudModeEnabled)
            toggleRow("Virtual Subwoofer", icon: "speaker.wave.2.bubble.left.fill", isOn: $audioManager.virtualSubwooferEnabled)
            valueSlider(title: "V-Sub Mix", value: $audioManager.virtualSubwooferMix, range: 0...1, step: 0.05, formatter: percentText)
                .disabled(!audioManager.virtualSubwooferEnabled)
            valueSlider(title: "V-Sub Cut", value: $audioManager.virtualSubwooferCutoff, range: 30...70, step: 1) { "\(Int($0)) Hz" }
                .disabled(!audioManager.virtualSubwooferEnabled)
        }
    }

    private var legacyCarModule: some View {
        rackModule(title: "Legacy Car Link", icon: "antenna.radiowaves.left.and.right", isActive: isLegacyCarChainActive) {
            toggleRow("AUX Signal Boost", icon: "arrow.up.forward.circle.fill", isOn: $audioManager.auxSignalBoostEnabled)
            valueSlider(title: "Preamp", value: $audioManager.auxSignalBoostDB, range: 0...12, step: 0.5, formatter: dbText)
                .disabled(!audioManager.auxSignalBoostEnabled)

            Divider().overlay(theme.accent.opacity(0.18))

            effectSlider(title: "FM Exciter", icon: "sparkles", isEnabled: $audioManager.fmExciterEnabled, value: $audioManager.fmExciterIntensity)
            toggleRow("Ground Hum Notch", icon: "waveform.path.ecg", isOn: $audioManager.groundLoopSuppressorEnabled)
            valueSlider(title: "Hum", value: $audioManager.groundLoopHumFrequency, range: 45...65, step: 1) { "\(Int($0)) Hz" }
                .disabled(!audioManager.groundLoopSuppressorEnabled)
            toggleRow("Engine Pitch Notch", icon: "engine.combustion", isOn: $audioManager.engineNoiseNotchEnabled)
                .disabled(!audioManager.groundLoopSuppressorEnabled)
            valueSlider(title: "Pitch", value: $audioManager.engineNoiseFrequency, range: 80...420, step: 5) { "\(Int($0)) Hz" }
                .disabled(!audioManager.groundLoopSuppressorEnabled || !audioManager.engineNoiseNotchEnabled)

            Divider().overlay(theme.accent.opacity(0.18))

            toggleRow("Anti-Boom Cabin Notch", icon: "speaker.slash.fill", isOn: $audioManager.cabinNotchEnabled)
            valueSlider(title: "Boom Freq", value: $audioManager.cabinNotchFrequency, range: 100...200, step: 1) { "\(Int($0)) Hz" }
                .disabled(!audioManager.cabinNotchEnabled)
            valueSlider(title: "Boom Cut", value: $audioManager.cabinNotchGain, range: -18...0, step: 0.5, formatter: dbText)
                .disabled(!audioManager.cabinNotchEnabled)

            Divider().overlay(theme.accent.opacity(0.18))

            toggleRow("Stereo Collapse", icon: "arrow.left.and.right.circle", isOn: $audioManager.stereoCollapseEnabled)
            valueSlider(title: "Width", value: $audioManager.stereoCollapseWidth, range: 0...1, step: 0.05, formatter: percentText)
                .disabled(!audioManager.stereoCollapseEnabled)
            toggleRow("Stereo3D", icon: "car.2.fill", isOn: $audioManager.logic7SpatializerEnabled)
            valueSlider(title: "Ambience", value: $audioManager.logic7Ambience, range: 0...1, step: 0.05, formatter: percentText)
                .disabled(!audioManager.logic7SpatializerEnabled)
            valueSlider(title: "Center", value: $audioManager.logic7CenterFocus, range: 0...1, step: 0.05, formatter: percentText)
                .disabled(!audioManager.logic7SpatializerEnabled)
            toggleRow("Final DAC Protection", icon: "shield.checkered", isOn: $audioManager.clipperProtectionEnabled)
        }
    }

    private func rackModule<Content: View>(title: String, icon: String, isActive: Bool, @ViewBuilder content: @escaping () -> Content) -> some View {
        EffectModuleCard(title: title, icon: icon, isActive: isActive, content: content)
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

    private func effectSlider(title: String, icon: String, isEnabled: Binding<Bool>, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            toggleRow(title, icon: icon, isOn: isEnabled)
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
            Text(LocalizedStringKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.mutedInk)
                .frame(width: 92, alignment: .leading)

            Slider(value: value, in: range, step: step)
                .tint(theme.secondaryAccent)

            Text(formatter(value.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.ink)
                .frame(width: 62, alignment: .trailing)
        }
        .opacity(isDisabledLook ? 0.55 : 1)
    }

    private var eightDMotionView: some View {
        GeometryReader { geometry in
            let position = CGFloat(min(max(audioManager.eightDAudioPosition, -1), 1))
            let x = (geometry.size.width - 22) * (position + 1) / 2 + 11

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.surface)
                    .overlay(Capsule().stroke(theme.accent.opacity(0.18), lineWidth: 1))

                Capsule()
                    .fill(
                        LinearGradient(colors: [theme.secondaryAccent.opacity(0.16), theme.accent.opacity(0.54)], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(x, 22))

                Circle()
                    .fill(theme.secondaryAccent)
                    .frame(width: 22, height: 22)
                    .shadow(color: theme.secondaryAccent.opacity(0.45), radius: 10, x: 0, y: 3)
                    .offset(x: x - 11)
                    .animation(.linear(duration: 0.08), value: audioManager.eightDAudioPosition)
            }
        }
        .frame(height: 22)
        .opacity(audioManager.eightDAudioEnabled ? 1 : 0.45)
    }

    private var isDisabledLook: Bool {
        false
    }

    private var isLegacyCarChainActive: Bool {
        audioManager.auxSignalBoostEnabled ||
        audioManager.fmExciterEnabled ||
        audioManager.groundLoopSuppressorEnabled ||
        audioManager.cabinNotchEnabled ||
        audioManager.virtualSubwooferEnabled ||
        audioManager.stereoCollapseEnabled ||
        audioManager.logic7SpatializerEnabled ||
        audioManager.clipperProtectionEnabled
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

private struct EffectModuleCard<Content: View>: View {
    @Environment(\.carAmbientTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded: Bool
    let title: String
    let icon: String
    let isActive: Bool
    let content: () -> Content

    init(title: String, icon: String, isActive: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.icon = icon; self.isActive = isActive; self.content = content
        _expanded = State(initialValue: title == "Tone Shaper")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon).frame(width: 24).foregroundStyle(isActive ? theme.accent : theme.mutedInk)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold)).foregroundStyle(theme.ink)
                        Text(isActive ? "Включён" : "Выключен").font(.caption).foregroundStyle(isActive ? theme.accent : theme.mutedInk)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(expanded ? 180 : 0)).foregroundStyle(theme.mutedInk)
                }
                .padding(16).frame(minHeight: 64).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "Развёрнуто" : "Свёрнуто")
            if expanded {
                VStack(alignment: .leading, spacing: 14, content: content)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            }
        }
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}
