import Foundation
import AVFoundation
import Combine
import Accelerate
import MediaPlayer

@MainActor
class AudioEngineManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrackTitle = "Нет трека"
    @Published var currentTrackID: UUID?

    @Published var bandCount = 5
    @Published var bandFrequencies: [Float] = AudioEngineManager.generateFrequencies(count: 5)
    @Published var bandGains: [Float] = Array(repeating: 0, count: 5)

    @Published var bassBoostEnabled = false { didSet { bassBoostPlugin.isEnabled = bassBoostEnabled } }
    @Published var trebleBoostEnabled = false { didSet { trebleBoostPlugin.isEnabled = trebleBoostEnabled } }
    @Published var loudnessEnabled = false { didSet { loudnessPlugin.isEnabled = loudnessEnabled } }

    @Published var volumeBoost: Float = 1 { didSet { volumeBoostPlugin.multiplier = Self.clampedVolumeBoost(volumeBoost) } }
    @Published var safeLoudModeEnabled = false {
        didSet {
            guard safeLoudModeEnabled else { return }
            applySafeLoudMode()
        }
    }

    @Published var compressorEnabled = false { didSet { compressorPlugin.isEnabled = compressorEnabled } }
    @Published var compressorThreshold: Float = -18 { didSet { compressorPlugin.threshold = compressorThreshold } }
    @Published var compressorRatio: Float = 3 { didSet { compressorPlugin.ratio = compressorRatio } }
    @Published var compressorAttack: Float = 0.012 { didSet { compressorPlugin.attack = compressorAttack } }
    @Published var compressorRelease: Float = 0.18 { didSet { compressorPlugin.release = compressorRelease } }

    @Published var limiterEnabled = true { didSet { limiterPlugin.isEnabled = limiterEnabled } }
    @Published var limiterCeiling: Float = -1 { didSet { limiterPlugin.ceiling = limiterCeiling } }
    @Published var limiterRelease: Float = 0.08 { didSet { limiterPlugin.release = limiterRelease } }

    @Published var stereoWideningEnabled = false { didSet { stereoWideningPlugin.isEnabled = stereoWideningEnabled } }
    @Published var stereoWideningIntensity: Float = 0.75 { didSet { stereoWideningPlugin.intensity = stereoWideningIntensity } }

    @Published var spatialAudioEnabled = false {
        didSet {
            spatialAudioPlugin.isEnabled = spatialAudioEnabled
            configureSpatialEnvironment()
        }
    }
    @Published var spatialAudioDepth: Float = 0.65 {
        didSet {
            spatialAudioPlugin.depth = spatialAudioDepth
            configureSpatialEnvironment()
        }
    }
    @Published var surroundEnabled = false {
        didSet {
            surroundPlugin.isEnabled = surroundEnabled
            configureSpatialEnvironment()
        }
    }
    @Published var surroundAmount: Float = 0.55 {
        didSet {
            surroundPlugin.amount = surroundAmount
            configureSpatialEnvironment()
        }
    }

    @Published var eightDAudioEnabled = false { didSet { configureSpatialEnvironment() } }
    @Published var eightDAudioIntensity: Float = 0.75 { didSet { configureSpatialEnvironment() } }
    @Published var eightDAudioSpeed: Float = 0.30 { didSet { configureSpatialEnvironment() } }

    @Published var softClipperEnabled = false { didSet { softClipperPlugin.isEnabled = softClipperEnabled } }

    @Published var reverbAmount: Float = 0 { didSet { reverbPlugin.amount = reverbAmount } }
    @Published var reverbSize: Float = 0.45 { didSet { reverbPlugin.size = reverbSize } }
    @Published var reverbDamping: Float = 0.35 { didSet { reverbPlugin.damping = reverbDamping } }

    @Published var currentLevel: Float = 0
    @Published var overloadPeak: Float = 0
    @Published var isOverloaded = false
    @Published var spectrumLevels: [Float] = Array(repeating: 0, count: 24)
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var waveformSamples: [Float] = Array(repeating: 0, count: WaveformAnalyzer.defaultSampleCount)

    @Published var inputGain: Float = 0.82 { didSet { inputGainNode?.outputVolume = min(max(inputGain, 0), 1.25) } }
    @Published var outputGain: Float = 0.90 { didSet { outputGainNode?.outputVolume = min(max(outputGain, 0), 1.25) } }

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var eqNode: AVAudioUnitEQ

    private let bassBoostPlugin = BassBoostPlugin()
    private let trebleBoostPlugin = TrebleBoostPlugin()
    private let loudnessPlugin = LoudnessPlugin()
    private let volumeBoostPlugin = VolumeBoostPlugin()
    private let compressorPlugin = CompressorPlugin()
    private let limiterPlugin = LimiterPlugin()
    private let softClipperPlugin = SoftClipperPlugin()
    private let stereoWideningPlugin = StereoWideningPlugin()
    private let spatialAudioPlugin = SpatialAudioPlugin()
    private let surroundPlugin = SurroundPlugin()
    private let reverbPlugin = ReverbPlugin()

    private var inputGainNode: AVAudioMixerNode?
    private var environmentNode: AVAudioEnvironmentNode?
    private var outputGainNode: AVAudioMixerNode?

    private var audioFile: AVAudioFile?
    private var currentFrame: AVAudioFramePosition = 0
    private var progressTimer: Timer?
    private var eightDRotationTimer: Timer?
    private var eightDRotationAngle: Float = 0
    private var isLevelMeteringActive = false
    private var shouldResumeAfterInterruption = false
    private var notificationObservers: [NSObjectProtocol] = []
    private var playbackScheduleID = UUID()
    var playbackFinished: (() -> Void)?
    var nextTrackRequested: (() -> Void)?
    var previousTrackRequested: (() -> Void)?

    private let spectrumFFTSize = 1024
    private let spectrumBandCount = 24
    private let spectrumWindow: [Float]
    private let spectrumLog2Size: vDSP_Length
    private var fftSetup: FFTSetup?

    init() {
        eqNode = AVAudioUnitEQ(numberOfBands: 5)
        spectrumWindow = Self.makeHannWindow(size: spectrumFFTSize)
        spectrumLog2Size = vDSP_Length(log2(Float(spectrumFFTSize)))
        fftSetup = vDSP_create_fftsetup(spectrumLog2Size, FFTRadix(kFFTRadix2))
        applyInitialPluginParameters()
        registerAudioSessionNotifications()
        configureRemoteCommandCenter()
        setupEngine()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        progressTimer?.invalidate()
        eightDRotationTimer?.invalidate()
        engine.mainMixerNode.removeTap(onBus: 0)
        playerNode.stop()
        engine.stop()
        MPRemoteCommandCenter.shared().playCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().pauseCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if let fftSetup { vDSP_destroy_fftsetup(fftSetup) }
    }

    static func generateFrequencies(count: Int) -> [Float] {
        guard count > 1 else { return [1000] }
        let minFreq: Float = 60
        let maxFreq: Float = 16000
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        return (0..<count).map { index in
            let t = Float(index) / Float(count - 1)
            return pow(10, logMin + t * (logMax - logMin))
        }
    }

    private static func clampedVolumeBoost(_ value: Float) -> Float {
        guard value.isFinite else { return 1 }
        return min(max(value, 1), 3)
    }

    private static func makeHannWindow(size: Int) -> [Float] {
        guard size > 1 else { return Array(repeating: 1, count: max(size, 0)) }
        return (0..<size).map { index in
            0.5 - 0.5 * cos((2 * Float.pi * Float(index)) / Float(size - 1))
        }
    }

    private func applyInitialPluginParameters() {
        stereoWideningPlugin.intensity = stereoWideningIntensity
        compressorPlugin.threshold = compressorThreshold
        compressorPlugin.ratio = compressorRatio
        compressorPlugin.attack = compressorAttack
        compressorPlugin.release = compressorRelease
        limiterPlugin.ceiling = limiterCeiling
        limiterPlugin.release = limiterRelease
        spatialAudioPlugin.depth = spatialAudioDepth
        surroundPlugin.amount = surroundAmount
        reverbPlugin.size = reverbSize
        reverbPlugin.damping = reverbDamping
    }

    private func setupEngine() {
        configureAudioSession()
        configureEQBands(node: eqNode, frequencies: bandFrequencies)

        let graph = AudioGraphBuilder.build(
            engine: engine,
            playerNode: playerNode,
            eqNode: eqNode,
            toneAndDynamicsNodes: [
                bassBoostPlugin.node,
                trebleBoostPlugin.node,
                loudnessPlugin.node,
                volumeBoostPlugin.node,
                compressorPlugin.node,
                limiterPlugin.node,
                softClipperPlugin.node,
                stereoWideningPlugin.node,
                spatialAudioPlugin.node,
                surroundPlugin.node
            ],
            reverbNode: reverbPlugin.node
        )

        inputGainNode = graph.inputGainNode
        environmentNode = graph.environmentNode
        outputGainNode = graph.outputGainNode
        inputGainNode?.outputVolume = inputGain
        outputGainNode?.outputVolume = outputGain
        configureSpatialEnvironment()
        startEngine()
    }

    private func configureSpatialEnvironment() {
        guard let environmentNode else { return }
        AudioGraphBuilder.configureEnvironment(
            environmentNode,
            spatialEnabled: spatialAudioEnabled,
            depth: spatialAudioDepth,
            surroundEnabled: surroundEnabled,
            surroundAmount: surroundAmount,
            eightDEnabled: eightDAudioEnabled,
            eightDIntensity: eightDAudioIntensity
        )
        if eightDAudioEnabled {
            updateEightDPosition()
            if isPlaying {
                startEightDRotation()
            }
        } else {
            stopEightDRotation()
        }
    }

    private func configureEQBands(node: AVAudioUnitEQ, frequencies: [Float]) {
        for (index, band) in node.bands.enumerated() {
            guard index < frequencies.count else { break }
            band.frequency = frequencies[index]
            band.filterType = .parametric
            band.bandwidth = 0.5
            band.gain = 0
            band.bypass = false
        }
    }

    private func startEngine() {
        do { try engine.start() } catch { print("Не удалось запустить AVAudioEngine: \(error)") }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .allowAirPlay])
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("Не удалось настроить AVAudioSession: \(error)")
        }
    }

    private func configureRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nextTrackRequested?() }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previousTrackRequested?() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func registerAudioSessionNotifications() {
        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleAudioSessionInterruption(notification)
                }
            },
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleRouteChange(notification)
                }
            },
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleMediaServicesReset()
                }
            },
            center.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: engine,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleEngineConfigurationChange()
                }
            }
        ]
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isPlaying
            if isPlaying {
                pause()
            }
            engine.pause()
        case .ended:
            configureAudioSession()
            startEngine()
            let optionValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionValue)
            if shouldResumeAfterInterruption && options.contains(.shouldResume) {
                play()
            }
            shouldResumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
        let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        let shouldResume = isPlaying

        switch reason {
        case .oldDeviceUnavailable:
            pause()
        case .newDeviceAvailable, .routeConfigurationChange, .categoryChange, .override:
            restartPlaybackGraph(resume: shouldResume)
        default:
            break
        }
    }

    private func handleMediaServicesReset() {
        let shouldResume = isPlaying
        restartPlaybackGraph(resume: shouldResume)
    }

    private func handleEngineConfigurationChange() {
        guard isPlaying else { return }
        restartPlaybackGraph(resume: true)
    }

    private func restartPlaybackGraph(resume: Bool) {
        if audioFile != nil {
            currentFrame = currentPlaybackFrame()
        }
        stopScheduledPlayback()
        engine.pause()
        configureAudioSession()
        startEngine()
        if resume {
            play()
        } else if audioFile != nil {
            schedulePlayback(from: currentFrame)
        }
    }

    func setBandCount(_ count: Int) {
        guard count != bandCount else { return }
        let wasPlaying = isPlaying
        engine.pause()

        engine.disconnectNodeOutput(eqNode)
        engine.disconnectNodeInput(eqNode)
        engine.detach(eqNode)

        let newFrequencies = Self.generateFrequencies(count: count)
        let newEQ = AVAudioUnitEQ(numberOfBands: count)
        engine.attach(newEQ)
        configureEQBands(node: newEQ, frequencies: newFrequencies)

        if let inputGainNode {
            engine.connect(inputGainNode, to: newEQ, format: nil)
        } else {
            engine.connect(playerNode, to: newEQ, format: nil)
        }
        engine.connect(newEQ, to: bassBoostPlugin.node, format: nil)

        eqNode = newEQ
        bandCount = count
        bandFrequencies = newFrequencies
        bandGains = Array(repeating: 0, count: count)

        startEngine()
        if wasPlaying { playerNode.play() }
    }

    func setBandGain(index: Int, value: Float) {
        guard index >= 0 && index < eqNode.bands.count else { return }
        eqNode.bands[index].gain = value
        if index < bandGains.count { bandGains[index] = value }
    }

    func applyGains(_ gains: [Float]) {
        for (index, value) in gains.enumerated() { setBandGain(index: index, value: value) }
    }

    func applyEffects(_ effects: PresetEffectSettings) {
        bassBoostEnabled = effects.bassBoostEnabled
        trebleBoostEnabled = effects.trebleBoostEnabled
        loudnessEnabled = effects.loudnessEnabled
        compressorEnabled = effects.compressorEnabled
        compressorThreshold = effects.compressorThreshold
        compressorRatio = effects.compressorRatio
        compressorAttack = effects.compressorAttack
        compressorRelease = effects.compressorRelease
        limiterEnabled = effects.limiterEnabled
        limiterCeiling = effects.limiterCeiling
        limiterRelease = effects.limiterRelease
        stereoWideningEnabled = effects.stereoWideningEnabled
        stereoWideningIntensity = effects.stereoWideningIntensity
        spatialAudioEnabled = effects.spatialAudioEnabled
        spatialAudioDepth = effects.spatialAudioDepth
        surroundEnabled = effects.surroundEnabled
        surroundAmount = effects.surroundAmount
        eightDAudioEnabled = effects.eightDAudioEnabled
        eightDAudioIntensity = effects.eightDAudioIntensity
        eightDAudioSpeed = effects.eightDAudioSpeed
        softClipperEnabled = effects.softClipperEnabled
        inputGain = effects.inputGain
        outputGain = effects.outputGain
        setVolumeBoost(effects.volumeBoost)
        reverbAmount = effects.reverbAmount
        reverbSize = effects.reverbSize
        reverbDamping = effects.reverbDamping
        if safeLoudModeEnabled {
            applySafeLoudMode()
        }
    }

    func currentEffectSettings() -> PresetEffectSettings {
        PresetEffectSettings(
            bassBoostEnabled: bassBoostEnabled,
            trebleBoostEnabled: trebleBoostEnabled,
            loudnessEnabled: loudnessEnabled,
            compressorEnabled: compressorEnabled,
            compressorThreshold: compressorThreshold,
            compressorRatio: compressorRatio,
            compressorAttack: compressorAttack,
            compressorRelease: compressorRelease,
            limiterEnabled: limiterEnabled,
            limiterCeiling: limiterCeiling,
            limiterRelease: limiterRelease,
            stereoWideningEnabled: stereoWideningEnabled,
            stereoWideningIntensity: stereoWideningIntensity,
            spatialAudioEnabled: spatialAudioEnabled,
            spatialAudioDepth: spatialAudioDepth,
            surroundEnabled: surroundEnabled,
            surroundAmount: surroundAmount,
            eightDAudioEnabled: eightDAudioEnabled,
            eightDAudioIntensity: eightDAudioIntensity,
            eightDAudioSpeed: eightDAudioSpeed,
            softClipperEnabled: softClipperEnabled,
            reverbAmount: reverbAmount,
            reverbSize: reverbSize,
            reverbDamping: reverbDamping,
            inputGain: inputGain,
            outputGain: outputGain,
            volumeBoost: volumeBoost
        )
    }

    func setVolumeBoost(_ value: Float) {
        let upperLimit: Float = safeLoudModeEnabled ? 1.35 : 3
        volumeBoost = min(Self.clampedVolumeBoost(value), upperLimit)
    }

    func resetAllEffects() {
        applyGains(Array(repeating: 0, count: bandCount))
        applyEffects(PresetEffectSettings(limiterEnabled: true))
    }

    private func applySafeLoudMode() {
        limiterEnabled = true
        limiterCeiling = min(limiterCeiling, -3)
        compressorEnabled = true
        compressorThreshold = min(compressorThreshold, -18)
        compressorRatio = max(compressorRatio, 3)
        inputGain = min(inputGain, 0.82)
        outputGain = min(outputGain, 0.82)
        setVolumeBoost(min(volumeBoost, 1.35))
    }

    func load(url: URL) {
        loadFile(url: url, title: url.deletingPathExtension().lastPathComponent, trackID: nil, durationHint: nil, waveformHint: nil)
    }

    func load(track: Track) {
        loadFile(
            url: track.fileURL,
            title: track.title,
            trackID: track.id,
            durationHint: track.duration > 0 ? track.duration : nil,
            waveformHint: track.waveformSamples
        )
    }

    private func loadFile(url: URL, title: String, trackID: UUID?, durationHint: Double?, waveformHint: [Float]?) {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let file = try AVAudioFile(forReading: url)
            audioFile = file
            currentTrackTitle = title
            currentTrackID = trackID
            duration = durationHint ?? Double(file.length) / file.processingFormat.sampleRate
            currentFrame = 0
            currentTime = 0
            waveformSamples = waveformHint ?? WaveformAnalyzer.samples(from: file)
            if waveformSamples.isEmpty {
                waveformSamples = Array(repeating: 0, count: WaveformAnalyzer.defaultSampleCount)
            }

            stopScheduledPlayback()
            schedulePlayback(from: currentFrame)
            updateNowPlayingInfo()
        } catch {
            print("Ошибка загрузки файла: \(error)")
        }
    }

    func play() {
        guard let file = audioFile else { return }
        configureAudioSession()
        if !engine.isRunning { startEngine() }
        if currentFrame >= file.length {
            currentFrame = 0
            currentTime = 0
        }
        stopScheduledPlayback()
        schedulePlayback(from: currentFrame)
        playerNode.play()
        isPlaying = true
        startProgressTimer()
        if eightDAudioEnabled {
            startEightDRotation()
        }
        updateNowPlayingInfo()
    }

    func pause() {
        currentFrame = currentPlaybackFrame()
        stopScheduledPlayback()
        isPlaying = false
        stopProgressTimer()
        stopEightDRotation()
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to time: Double) {
        guard let file = audioFile else { return }
        let clampedTime = min(max(time, 0), duration)
        let targetFrame = AVAudioFramePosition(clampedTime * file.processingFormat.sampleRate)
        let wasPlaying = isPlaying

        currentFrame = min(max(targetFrame, 0), file.length)
        currentTime = clampedTime
        stopScheduledPlayback()

        guard currentFrame < file.length else {
            isPlaying = false
            stopProgressTimer()
            stopEightDRotation()
            updateNowPlayingInfo()
            return
        }

        schedulePlayback(from: currentFrame)
        if wasPlaying {
            playerNode.play()
            startProgressTimer()
        }
        updateNowPlayingInfo()
    }

    private func stopScheduledPlayback() {
        playbackScheduleID = UUID()
        playerNode.stop()
    }

    private func schedulePlayback(from frame: AVAudioFramePosition) {
        guard let file = audioFile, frame < file.length else { return }
        let scheduleID = UUID()
        playbackScheduleID = scheduleID
        let remainingFrames = file.length - frame
        let frameCount = AVAudioFrameCount(min(remainingFrames, AVAudioFramePosition(UInt32.max)))
        playerNode.scheduleSegment(file, startingFrame: frame, frameCount: frameCount, at: nil) {
            Task { @MainActor [weak self] in
                guard let manager = self, manager.playbackScheduleID == scheduleID else { return }
                manager.isPlaying = false
                manager.currentFrame = 0
                manager.currentTime = 0
                manager.stopProgressTimer()
                manager.stopEightDRotation()
                manager.updateNowPlayingInfo()
                manager.playbackFinished?()
            }
        }
    }

    private func currentPlaybackFrame() -> AVAudioFramePosition {
        guard let file = audioFile,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return currentFrame
        }
        let frame = currentFrame + playerTime.sampleTime
        return min(max(frame, 0), file.length)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let manager = self, let file = manager.audioFile else { return }
                let frame = manager.currentPlaybackFrame()
                manager.currentTime = Double(frame) / file.processingFormat.sampleRate
                manager.updateNowPlayingElapsedTime()
            }
        }
    }

    private func updateNowPlayingInfo() {
        guard duration > 0 else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentTrackTitle,
            MPMediaItemPropertyArtist: "EqualizerCar",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
    }

    private func updateNowPlayingElapsedTime() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            updateNowPlayingInfo()
            return
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func startEightDRotation() {
        guard eightDRotationTimer == nil else { return }
        updateEightDPosition()
        eightDRotationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.updateEightDPosition()
            }
        }
    }

    private func stopEightDRotation() {
        eightDRotationTimer?.invalidate()
        eightDRotationTimer = nil
        eightDRotationAngle = 0
        outputGainNode?.pan = 0
    }

    private func updateEightDPosition() {
        guard eightDAudioEnabled else { return }
        let clampedIntensity = min(max(eightDAudioIntensity, 0), 1)
        let clampedSpeed = min(max(eightDAudioSpeed, 0.03), 0.75)
        let radius = 0.8 + clampedIntensity * 2.8
        let depth = -1.1 - clampedIntensity * 1.8

        eightDRotationAngle += clampedSpeed * 0.14
        let x = sin(eightDRotationAngle) * radius
        let z = depth + cos(eightDRotationAngle) * radius * 0.45
        environmentNode?.position = AVAudioMake3DPoint(x, 0, z)

        // AVAudioEnvironmentNode spatializes mono sources best. Most imported songs are stereo,
        // so pan automation is the guaranteed audible 8D movement for regular MP3 files.
        let pan = sin(eightDRotationAngle) * min(0.95, clampedIntensity)
        outputGainNode?.pan = pan
    }

    func startLevelMetering() {
        guard !isLevelMeteringActive else { return }
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
            Task { @MainActor in self?.updateMeters(with: samples) }
        }
        isLevelMeteringActive = true
    }

    func stopLevelMetering() {
        guard isLevelMeteringActive else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        isLevelMeteringActive = false
        currentLevel = 0
        spectrumLevels = Array(repeating: 0, count: spectrumBandCount)
    }

    private func updateMeters(with samples: [Float]) {
        guard !samples.isEmpty else { return }
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        currentLevel = rms
        overloadPeak = samples.reduce(Float(0)) { max($0, abs($1)) }
        isOverloaded = overloadPeak >= 0.98 || rms >= 0.78
        spectrumLevels = calculateSpectrumLevels(from: samples)
    }

    private func calculateSpectrumLevels(from samples: [Float]) -> [Float] {
        guard samples.count >= spectrumFFTSize, let fftSetup else {
            return Array(repeating: 0, count: spectrumBandCount)
        }

        var windowedSamples = Array(samples.prefix(spectrumFFTSize))
        vDSP_vmul(windowedSamples, 1, spectrumWindow, 1, &windowedSamples, 1, vDSP_Length(spectrumFFTSize))

        var real = Array(repeating: Float(0), count: spectrumFFTSize / 2)
        var imaginary = Array(repeating: Float(0), count: spectrumFFTSize / 2)
        var magnitudes = Array(repeating: Float(0), count: spectrumFFTSize / 2)

        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                var splitComplex = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                windowedSamples.withUnsafeBufferPointer { samplesPointer in
                    samplesPointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: spectrumFFTSize / 2) { complexPointer in
                        vDSP_ctoz(complexPointer, 2, &splitComplex, 1, vDSP_Length(spectrumFFTSize / 2))
                    }
                }
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, spectrumLog2Size, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(spectrumFFTSize / 2))
            }
        }

        return makeLogarithmicBands(from: magnitudes)
    }

    private func makeLogarithmicBands(from magnitudes: [Float]) -> [Float] {
        let usableBinCount = max(magnitudes.count - 1, 1)
        return (0..<spectrumBandCount).map { bandIndex in
            let lowerRatio = Float(bandIndex) / Float(spectrumBandCount)
            let upperRatio = Float(bandIndex + 1) / Float(spectrumBandCount)
            let lowerBin = max(1, Int(pow(upperRatioBase, lowerRatio) * Float(usableBinCount) / upperRatioBase))
            let upperBin = max(lowerBin + 1, Int(pow(upperRatioBase, upperRatio) * Float(usableBinCount) / upperRatioBase))
            let clampedUpperBin = min(upperBin, magnitudes.count)
            let slice = magnitudes[lowerBin..<clampedUpperBin]
            let average = slice.reduce(Float(0), +) / Float(max(slice.count, 1))
            let decibels = 10 * log10(max(average, 0.000_000_1))
            return min(max((decibels + 90) / 90, 0), 1)
        }
    }

    private var upperRatioBase: Float { 40 }
}
