import SwiftUI
import UIKit

struct NoLookGestureControlView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var library: LibraryManager
    @ObservedObject var presetManager: PresetManager
    @Environment(\.carAmbientTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var twoFingerMode: TwoFingerControlMode = .volume
    @State private var selectedPresetIndex = 0

    var body: some View {
        ZStack {
            theme.screenBackground.ignoresSafeArea()

            NoLookGesturePad(
                onSingleTap: {
                    audioManager.togglePlayPause()
                },
                onHorizontalSwipe: { direction in
                    switch direction {
                    case .left:
                        audioManager.nextTrackRequested?()
                    case .right:
                        audioManager.previousTrackRequested?()
                    }
                },
                onTwoFingerVerticalSwipe: { direction in
                    switch twoFingerMode {
                    case .volume:
                        adjustOutputGain(by: direction == .up ? 0.04 : -0.04)
                    case .preset:
                        cycleLegacyProfile(forward: direction == .up)
                    }
                }
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                Spacer()

                VStack(spacing: 12) {
                    Picker("Two-finger swipe", selection: $twoFingerMode) {
                        ForEach(TwoFingerControlMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)

                    Text(audioManager.currentTrackTitle)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.ink)

                    HStack(spacing: 14) {
                        Label(audioManager.isPlaying ? "Playing" : "Paused", systemImage: audioManager.isPlaying ? "play.fill" : "pause.fill")
                        Text("Output \(Int(audioManager.outputGain * 100))%")
                        if twoFingerMode == .preset {
                            Text(activeLegacyProfileName)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.mutedInk)
                }
                .padding(16)
            }
            .padding(20)
        }
    }

    private var activeLegacyProfileName: String {
        guard LegacyCarAudioProfile.all.indices.contains(selectedPresetIndex) else { return "Legacy Preset" }
        return LegacyCarAudioProfile.all[selectedPresetIndex].name
    }

    private func adjustOutputGain(by delta: Float) {
        audioManager.outputGain = min(max(audioManager.outputGain + delta, 0), 1.25)
    }

    private func cycleLegacyProfile(forward: Bool) {
        guard !LegacyCarAudioProfile.all.isEmpty else { return }
        let offset = forward ? 1 : -1
        selectedPresetIndex = (selectedPresetIndex + offset + LegacyCarAudioProfile.all.count) % LegacyCarAudioProfile.all.count
        let profile = LegacyCarAudioProfile.all[selectedPresetIndex]
        audioManager.applyLegacyCarProfile(profile)
        if let preset = presetManager.presets.first(where: { $0.name == profile.name }) {
            presetManager.activePresetID = preset.id
        }
    }
}

private enum TwoFingerControlMode: String, CaseIterable, Identifiable {
    case volume = "Volume"
    case preset = "Preset"

    var id: String { rawValue }
}

private enum HorizontalSwipeDirection {
    case left
    case right
}

private enum VerticalSwipeDirection {
    case up
    case down
}

private struct NoLookGesturePad: UIViewRepresentable {
    let onSingleTap: () -> Void
    let onHorizontalSwipe: (HorizontalSwipeDirection) -> Void
    let onTwoFingerVerticalSwipe: (VerticalSwipeDirection) -> Void

    func makeUIView(context: Context) -> TouchPadView {
        let view = TouchPadView()
        view.onSingleTap = onSingleTap
        view.onHorizontalSwipe = onHorizontalSwipe
        view.onTwoFingerVerticalSwipe = onTwoFingerVerticalSwipe
        return view
    }

    func updateUIView(_ uiView: TouchPadView, context: Context) {
        uiView.onSingleTap = onSingleTap
        uiView.onHorizontalSwipe = onHorizontalSwipe
        uiView.onTwoFingerVerticalSwipe = onTwoFingerVerticalSwipe
    }
}

private final class TouchPadView: UIView {
    var onSingleTap: (() -> Void)?
    var onHorizontalSwipe: ((HorizontalSwipeDirection) -> Void)?
    var onTwoFingerVerticalSwipe: ((VerticalSwipeDirection) -> Void)?

    private var startPoint: CGPoint = .zero
    private var startTouchCount = 0
    private var startTime: TimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        startPoint = touch.location(in: self)
        startTouchCount = event?.allTouches?.count ?? touches.count
        startTime = touch.timestamp
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let endPoint = touch.location(in: self)
        let delta = CGPoint(x: endPoint.x - startPoint.x, y: endPoint.y - startPoint.y)
        let duration = touch.timestamp - startTime
        let distance = hypot(delta.x, delta.y)

        if startTouchCount >= 2, abs(delta.y) > 70, abs(delta.y) > abs(delta.x) * 1.2 {
            onTwoFingerVerticalSwipe?(delta.y < 0 ? .up : .down)
            return
        }

        if abs(delta.x) > 80, abs(delta.x) > abs(delta.y) * 1.2 {
            onHorizontalSwipe?(delta.x < 0 ? .left : .right)
            return
        }

        if startTouchCount == 1, distance < 18, duration < 0.35 {
            onSingleTap?()
        }
    }
}

#Preview {
    NoLookGestureControlView(
        audioManager: AudioEngineManager(),
        library: LibraryManager(),
        presetManager: PresetManager()
    )
}
