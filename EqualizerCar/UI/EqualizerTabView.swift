import SwiftUI

struct EqualizerTabView: View {
    @ObservedObject var audioManager: AudioEngineManager
    var presetManager: PresetManager? = nil
    @Environment(\.carAmbientTheme) private var theme
    var isEmbedded = false
    var body: some View {
        Group {
            if isEmbedded { content }
            else { ScrollView { content.padding(24) }.background(theme.background).navigationTitle("Equalizer") }
        }
    }
    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shape your sound").font(.title3.weight(.semibold)).foregroundStyle(theme.ink)
                    Text("\(audioManager.bandCount)-band equalizer").font(.caption).foregroundStyle(theme.mutedInk)
                }
                Spacer()
                Toggle("Equalizer", isOn: $audioManager.isEqualizerEnabled).labelsHidden()
                    .tint(theme.accent).accessibilityLabel("Enable equalizer")
            }
            if let presetManager { StudioPresetSelector(audio: audioManager, presets: presetManager) }
            VStack(spacing: 16) {
                HStack {
                    Text("EQ CURVE").font(.system(size: 10, weight: .medium)).tracking(2)
                    Spacer()
                    Text(audioManager.isEqualizerEnabled ? "ACTIVE" : "BYPASSED").font(.system(size: 10, weight: .medium)).tracking(1)
                }.foregroundStyle(theme.mutedInk)
                EqualizerCurveView(audioManager: audioManager)
                HStack { Text("35 Hz"); Spacer(); Text("1 kHz"); Spacer(); Text("16 kHz") }
                    .font(.system(size: 10).monospacedDigit()).foregroundStyle(theme.mutedInk)
            }.padding(20).background(theme.surface, in: RoundedRectangle(cornerRadius: 24))
            VStack(spacing: 20) {
                HStack {
                    Text("Bands").font(.subheadline.weight(.medium)).foregroundStyle(theme.ink)
                    Spacer()
                    Picker("Bands", selection: Binding(get: { audioManager.bandCount }, set: { audioManager.setBandCount($0) })) {
                        Text("5").tag(5); Text("10").tag(10); Text("20").tag(20)
                    }.pickerStyle(.segmented).frame(width: 168)
                }
                HStack(alignment: .top, spacing: 4) {
                    VStack { Text("+24"); Spacer(); Text("0 dB"); Spacer(); Text("−24") }
                        .font(.system(size: 9).monospacedDigit()).foregroundStyle(theme.mutedInk)
                        .frame(width: 30, height: 176).padding(.top, 26)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 4) {
                            ForEach(Array(audioManager.bandFrequencies.enumerated()), id: \.offset) { index, frequency in
                                VStack(spacing: 8) {
                                    StudioEQSlider(value: Binding(
                                        get: { audioManager.bandGains.indices.contains(index) ? audioManager.bandGains[index] : 0 },
                                        set: { audioManager.setBandGain(index: index, value: $0) }
                                    ), frequency: frequency)
                                    Menu {
                                        ForEach(EQBandFilterType.allCases) { type in
                                            Button(type.localizedTitle) { audioManager.setBandFilterType(index: index, type: type) }
                                        }
                                        Button("Reset band") { audioManager.setBandGain(index: index, value: 0) }
                                    } label: {
                                        Image(systemName: audioManager.bandFilterTypes.indices.contains(index) ? audioManager.bandFilterTypes[index].systemImage : "slider.vertical.3")
                                            .font(.caption).foregroundStyle(theme.mutedInk).frame(width: 44, height: 36)
                                    }.accessibilityLabel("Filter type for \(Int(frequency)) Hz")
                                }
                            }
                        }
                    }
                }
                .opacity(audioManager.isEqualizerEnabled ? 1 : 0.35)
                .disabled(!audioManager.isEqualizerEnabled)
                HStack {
                    Text("Swipe for more bands").font(.caption).foregroundStyle(theme.mutedInk)
                    Spacer()
                    Button("Reset EQ") { audioManager.applyGains(Array(repeating: 0, count: audioManager.bandCount)) }
                        .font(.caption.weight(.medium)).foregroundStyle(theme.ink)
                }
            }.padding(16).background(theme.surface, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

struct StudioEQSlider: View {
    @Binding var value: Float
    let frequency: Float
    @Environment(\.carAmbientTheme) private var theme
    @State private var touched = false
    var body: some View {
        VStack(spacing: 12) {
            Text(String(format: "%+.1f", value)).font(.system(size: 10).monospacedDigit()).foregroundStyle(theme.mutedInk)
            GeometryReader { geometry in
                let height = max(geometry.size.height - 16, 1)
                let position = CGFloat((24 - min(max(value, -24), 24)) / 48) * height + 8
                ZStack(alignment: .top) {
                    Capsule().fill(theme.mutedInk.opacity(0.18)).frame(width: 3).padding(.vertical, 8)
                    Rectangle().fill(theme.mutedInk.opacity(0.3)).frame(width: 16, height: 1).offset(y: geometry.size.height / 2)
                    Capsule().fill(theme.ink.opacity(0.8)).frame(width: 3, height: abs(position - geometry.size.height / 2))
                        .offset(y: min(position, geometry.size.height / 2))
                    Circle().fill(theme.accent).frame(width: 14, height: 14)
                        .shadow(color: theme.accent.opacity(touched ? 0.25 : 0), radius: 8)
                        .offset(y: position - 7)
                }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                        touched = true
                        let gain = 24 - Float((gesture.location.y - 8) / height) * 48
                        value = (min(max(gain, -24), 24) * 2).rounded() / 2
                    }.onEnded { _ in touched = false })
            }.frame(height: 176)
            Text(frequency >= 1000 ? String(format: "%.1fk", frequency / 1000) : "\(Int(frequency))")
                .font(.system(size: 10).monospacedDigit()).foregroundStyle(theme.mutedInk)
        }.frame(width: 44)
            .accessibilityElement().accessibilityLabel("\(Int(frequency)) Hz")
            .accessibilityValue(String(format: "%.1f decibels", value))
            .accessibilityAdjustableAction { direction in value = min(max(value + (direction == .increment ? 0.5 : -0.5), -24), 24) }
    }
}
