import Foundation
import AVFoundation
import Combine
import Observation
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
    @Published var bandFilterTypes: [EQBandFilterType] = Array(repeating: .parametric, count: 5)

    @Published var bassBoostEnabled = false { didSet { bassBoostPlugin.isEnabled = bassBoostEnabled } }
    @Published var bassBoostIntensity: Float = 8 { didSet { bassBoostPlugin.intensity = bassBoostIntensity } }
    @Published var bassBoostFrequency: Float = 80 { didSet { bassBoostPlugin.frequency = bassBoostFrequency } }
    @Published var virtualSubwooferEnabled = false { didSet { virtualSubwooferPlugin.isEnabled = virtualSubwooferEnabled } }
    @Published var virtualSubwooferMix: Float = 0 { didSet { virtualSubwooferPlugin.mix = virtualSubwooferMix } }
    @Published var virtualSubwooferCutoff: Float = 55 { didSet { virtualSubwooferPlugin.cutoffFrequency = virtualSubwooferCutoff } }
    @Published var cabinNotchEnabled = false { didSet { cabinNotchFilterPlugin.isEnabled = cabinNotchEnabled } }
    @Published var cabinNotchFrequency: Float = 135 { didSet { cabinNotchFilterPlugin.frequency = cabinNotchFrequency } }
    @Published var cabinNotchQ: Float = 6 { didSet { cabinNotchFilterPlugin.qFactor = cabinNotchQ } }
    @Published var cabinNotchGain: Float = -6 { didSet { cabinNotchFilterPlugin.gain = cabinNotchGain } }
    @Published var adaptiveBassBoostEnabled: Bool = false {
        didSet {
            if adaptiveBassBoostEnabled {
                startAdaptiveBassTimerIfNeeded()
            } else {
                stopAdaptiveBassTimer()
            }
        }
    }
    @Published var smartLoudBassMode: SmartLoudBassMode = .clean
    @Published var subBassGain: Float = 0 { didSet { if !isBatchingBassLabChanges { applyBassLabEQ() } } }
    @Published var punchBassGain: Float = 0 { didSet { if !isBatchingBassLabChanges { applyBassLabEQ() } } }
    @Published var warmthGain: Float = 0 { didSet { if !isBatchingBassLabChanges { applyBassLabEQ() } } }
    @Published var bassTightness: Float = 0.5 { didSet { if !isBatchingBassLabChanges { applyBassTightness() } } }
    @Published var subwooferModeEnabled: Bool = false {
        didSet {
            crossoverEnabled = subwooferModeEnabled || bassMonoBelow100Enabled
            crossoverMode = subwooferModeEnabled ? .subwoofer : crossoverMode
        }
    }
    @Published var bassMonoBelow100Enabled: Bool = false {
        didSet {
            crossoverEnabled = bassMonoBelow100Enabled || subwooferModeEnabled
            if bassMonoBelow100Enabled {
                crossoverFrequency = min(crossoverFrequency, 100)
            }
        }
    }

    // internal smoothing state for adaptive bass
    private var adaptiveTargetGain: Float = 0
    private var adaptiveCurrentGain: Float = 0
    private var adaptiveTimer: Timer?
    private var isBatchingBassLabChanges = false
    @Published var trebleBoostEnabled = false { didSet { trebleBoostPlugin.isEnabled = trebleBoostEnabled } }
    @Published var loudnessEnabled = false { didSet { loudnessPlugin.isEnabled = loudnessEnabled } }

    @Published var volumeBoost: Float = 1 { didSet { volumeBoostPlugin.multiplier = Self.clampedVolumeBoost(volumeBoost) } }
    @Published var auxSignalBoostEnabled = false { didSet { auxSignalBoostPlugin.isEnabled = auxSignalBoostEnabled } }
    @Published var auxSignalBoostDB: Float = 0 { didSet { auxSignalBoostPlugin.gainDB = auxSignalBoostDB } }
    @Published var fmExciterEnabled = false { didSet { fmExciterPlugin.isEnabled = fmExciterEnabled } }
    @Published var fmExciterIntensity: Float = 0.35 { didSet { fmExciterPlugin.intensity = fmExciterIntensity } }
    @Published var groundLoopSuppressorEnabled = false { didSet { groundLoopSuppressorPlugin.isEnabled = groundLoopSuppressorEnabled } }
    @Published var groundLoopHumFrequency: Float = 50 { didSet { groundLoopSuppressorPlugin.humFrequency = groundLoopHumFrequency } }
    @Published var engineNoiseNotchEnabled = false { didSet { groundLoopSuppressorPlugin.enginePitchTrackingEnabled = engineNoiseNotchEnabled } }
    @Published var engineNoiseFrequency: Float = 120 { didSet { groundLoopSuppressorPlugin.enginePitchFrequency = engineNoiseFrequency } }
    @Published var stereoCollapseEnabled = false { didSet { stereoCollapsePlugin.isEnabled = stereoCollapseEnabled } }
    @Published var stereoCollapseWidth: Float = 1 { didSet { stereoCollapsePlugin.width = stereoCollapseWidth } }
    @Published var clipperProtectionEnabled = true { didSet { clipperProtectionPlugin.isEnabled = clipperProtectionEnabled } }
    @Published var logic7SpatializerEnabled = false { didSet { logic7SpatializerPlugin.isEnabled = logic7SpatializerEnabled } }
    @Published var logic7Ambience: Float = 0.35 { didSet { logic7SpatializerPlugin.ambience = logic7Ambience } }
    @Published var logic7CenterFocus: Float = 0.45 { didSet { logic7SpatializerPlugin.centerFocus = logic7CenterFocus } }
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

    @Published var multibandCompressorEnabled: Bool = false {
        didSet { multibandCompressor.isEnabled = multibandCompressorEnabled }
    }

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
    @Published var eightDAudioMode: EightDAudioMode = .beatReactive { didSet { configureSpatialEnvironment() } }

    @Published var softClipperEnabled = false { didSet { softClipperPlugin.isEnabled = softClipperEnabled } }

    @Published var reverbAmount: Float = 0 { didSet { reverbPlugin.amount = reverbAmount } }
    @Published var reverbSize: Float = 0.45 { didSet { reverbPlugin.size = reverbSize } }
    @Published var reverbDamping: Float = 0.35 { didSet { reverbPlugin.damping = reverbDamping } }
    @Published var crossoverEnabled: Bool = false {
        didSet { crossoverPlugin.isEnabled = crossoverEnabled }
    }
    @Published var crossoverFrequency: Float = 80 { didSet { crossoverPlugin.crossoverFrequency = crossoverFrequency } }
    @Published var crossoverMode: CrossoverMode = .subwoofer { didSet { crossoverPlugin.mode = crossoverMode } }
    @Published var subwooferPhaseInverted: Bool = false {
        didSet { phaseInverterPlugin.isEnabled = subwooferPhaseInverted }
    }

    // High-frequency values are observed only by views that read them.
    let telemetry = AudioTelemetry()
    var currentLevel: Float {
        get { telemetry.currentLevel }
        set { telemetry.currentLevel = newValue }
    }
    var overloadPeak: Float {
        get { telemetry.overloadPeak }
        set { telemetry.overloadPeak = newValue }
    }
    var inputPeak: Float {
        get { telemetry.inputPeak }
        set { telemetry.inputPeak = newValue }
    }
    var outputPeak: Float {
        get { telemetry.outputPeak }
        set { telemetry.outputPeak = newValue }
    }
    var rmsLevel: Float {
        get { telemetry.rmsLevel }
        set { telemetry.rmsLevel = newValue }
    }
    var lufsApprox: Float {
        get { telemetry.lufsApprox }
        set { telemetry.lufsApprox = newValue }
    }
    var dynamicRange: Float {
        get { telemetry.dynamicRange }
        set { telemetry.dynamicRange = newValue }
    }
    var gainReduction: Float {
        get { telemetry.gainReduction }
        set { telemetry.gainReduction = newValue }
    }
    var limiterActive: Bool {
        get { telemetry.limiterActive }
        set { telemetry.limiterActive = newValue }
    }
    var clippingRisk: Float {
        get { telemetry.clippingRisk }
        set { telemetry.clippingRisk = newValue }
    }
    var isOverloaded: Bool {
        get { telemetry.isOverloaded }
        set { telemetry.isOverloaded = newValue }
    }
    var spectrumLevels: [Float] {
        get { telemetry.spectrumLevels }
        set { telemetry.spectrumLevels = newValue }
    }
    var eightDAudioPosition: Float {
        get { telemetry.eightDAudioPosition }
        set { telemetry.eightDAudioPosition = newValue }
    }
    var currentTime: Double {
        get { telemetry.currentTime }
        set { telemetry.currentTime = newValue }
    }
    @Published var duration: Double = 0
    @Published var waveformSamples: [Float] = Array(repeating: 0, count: WaveformAnalyzer.defaultSampleCount)

    @Published var inputGain: Float = 0.82 { didSet { inputGainNode?.outputVolume = min(max(inputGain, 0), 1.25) } }
    @Published var outputGain: Float = 0.90 { didSet { outputGainNode?.outputVolume = min(max(outputGain, 0), 1.25) } }
    @Published var stereoBalance: Float = 0 { didSet { updateOutputPan() } } // -1..1 left..right
    @Published var frontRearFader: Float = 0 { didSet { /* TODO: route to front/rear buses when available */ } }

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var eqNode: AVAudioUnitEQ

    private let bassBoostPlugin = BassBoostPlugin()
    private let virtualSubwooferPlugin = VirtualSubwooferPlugin()
    private let cabinNotchFilterPlugin = CabinNotchFilterPlugin()
    private let trebleBoostPlugin = TrebleBoostPlugin()
    private let crossoverPlugin = CrossoverPlugin()
    private let loudnessPlugin = LoudnessPlugin()
    private let volumeBoostPlugin = VolumeBoostPlugin()
    private let auxSignalBoostPlugin = AUXSignalBoostPlugin()
    private let fmExciterPlugin = FMDynamicExciterPlugin()
    private let groundLoopSuppressorPlugin = GroundLoopNoiseSuppressorPlugin()
    private let stereoCollapsePlugin = StereoWidthCollapsePlugin()
    private let clipperProtectionPlugin = ClipperProtectionPlugin()
    private let logic7SpatializerPlugin = Logic7SpatializerPlugin()
    private let compressorPlugin = CompressorPlugin()
    private let limiterPlugin = LimiterPlugin()
    private let softClipperPlugin = SoftClipperPlugin()
    private let stereoWideningPlugin = StereoWideningPlugin()
    private let spatialAudioPlugin = SpatialAudioPlugin()
    private let surroundPlugin = SurroundPlugin()
    private let reverbPlugin = ReverbPlugin()
    private let multibandCompressor = MultibandCompressorPlugin()
    private let phaseInverterPlugin = PhaseInverterPlugin()

    private var inputGainNode: AVAudioMixerNode?
    private var environmentNode: AVAudioEnvironmentNode?
    private var outputGainNode: AVAudioMixerNode?

    private var audioFile: AVAudioFile?
    private var currentFrame: AVAudioFramePosition = 0
    private var lastNowPlayingRefresh = Date.distantPast
    private var progressTimer: Timer?
    private var eightDRotationTimer: Timer?
    private var eightDRotationAngle: Float = 0
    private var eightDPan: Float = 0
    private var eightDEnergyEnvelope: Float = 0
    private var eightDPreviousBassEnergy: Float = 0
    private var isLevelMeteringActive = false
    private var shouldResumeAfterInterruption = false
    private var notificationObservers: [NSObjectProtocol] = []
    private var playbackScheduleID = UUID()
    private var lastMeterUpdate = Date.distantPast
    private var lastClippingGuardUpdate = Date.distantPast
    var playbackFinished: (() -> Void)?
    var nextTrackRequested: (() -> Void)?
    var previousTrackRequested: (() -> Void)?

    private let spectrumFFTSize = 1024
    private let spectrumBandCount = 16
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
        let minFreq: Float = 35
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
        bassBoostPlugin.intensity = bassBoostIntensity
        bassBoostPlugin.frequency = bassBoostFrequency
        virtualSubwooferPlugin.mix = virtualSubwooferMix
        virtualSubwooferPlugin.cutoffFrequency = virtualSubwooferCutoff
        virtualSubwooferPlugin.isEnabled = virtualSubwooferEnabled
        cabinNotchFilterPlugin.frequency = cabinNotchFrequency
        cabinNotchFilterPlugin.qFactor = cabinNotchQ
        cabinNotchFilterPlugin.gain = cabinNotchGain
        cabinNotchFilterPlugin.isEnabled = cabinNotchEnabled
        auxSignalBoostPlugin.gainDB = auxSignalBoostDB
        fmExciterPlugin.intensity = fmExciterIntensity
        groundLoopSuppressorPlugin.humFrequency = groundLoopHumFrequency
        groundLoopSuppressorPlugin.enginePitchFrequency = engineNoiseFrequency
        groundLoopSuppressorPlugin.enginePitchTrackingEnabled = engineNoiseNotchEnabled
        stereoCollapsePlugin.width = stereoCollapseWidth
        clipperProtectionPlugin.isEnabled = clipperProtectionEnabled
        logic7SpatializerPlugin.ambience = logic7Ambience
        logic7SpatializerPlugin.centerFocus = logic7CenterFocus
        adaptiveBassBoostEnabled = false
        // crossover defaults will be configured later if needed
        crossoverPlugin.crossoverFrequency = 80
        crossoverPlugin.mode = .subwoofer
        crossoverPlugin.isEnabled = false
        phaseInverterPlugin.isEnabled = false
    }

    private func setupEngine() {
        configureAudioSession()
        configureEQBands(node: eqNode, frequencies: bandFrequencies)

        let graph = AudioGraphBuilder.build(
            engine: engine,
            playerNode: playerNode,
            eqNode: eqNode,
            preEQNodes: [
                auxSignalBoostPlugin.node
            ],
            toneAndDynamicsNodes: [
                    crossoverPlugin.node,
                    phaseInverterPlugin.node,
                groundLoopSuppressorPlugin.node,
                cabinNotchFilterPlugin.node,
                virtualSubwooferPlugin.node,
                bassBoostPlugin.node,
                trebleBoostPlugin.node,
                fmExciterPlugin.node,
                loudnessPlugin.node,
                volumeBoostPlugin.node,
                compressorPlugin.node,
                limiterPlugin.node,
                multibandCompressor.node,
                softClipperPlugin.node,
                stereoCollapsePlugin.node,
                stereoWideningPlugin.node,
                spatialAudioPlugin.node,
                surroundPlugin.node,
                logic7SpatializerPlugin.node
            ],
            reverbNode: reverbPlugin.node,
            finalProtectionNode: clipperProtectionPlugin.node
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
            band.filterType = eqFilterType(for: bandFilterTypes.indices.contains(index) ? bandFilterTypes[index] : .parametric)
            band.bandwidth = 0.5
            band.gain = 0
            band.bypass = false
        }
    }

    private func eqFilterType(for type: EQBandFilterType) -> AVAudioUnitEQFilterType {
        switch type {
        case .parametric:
            return .parametric
        case .lowShelf:
            return .lowShelf
        case .highShelf:
            return .highShelf
        case .notch:
            return .bandStop
        case .highPass:
            return .highPass
        case .lowPass:
            return .lowPass
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
        guard count > 0 else { return }

        let wasPlaying = isPlaying
        if audioFile != nil {
            currentFrame = currentPlaybackFrame()
        }
        isPlaying = false
        stopScheduledPlayback()
        stopProgressTimer()
        stopEightDRotation()
        engine.pause()

        let oldCount = bandCount
        let oldGains = bandGains
        let oldFilterTypes = bandFilterTypes

        let newFrequencies = Self.generateFrequencies(count: count)
        let newEQ = AVAudioUnitEQ(numberOfBands: count)
        engine.attach(newEQ)
        configureEQBands(node: newEQ, frequencies: newFrequencies)

        // Interpolate old gains to new band's positions (index-based interpolation)
        var interpolatedGains = Array(repeating: Float(0), count: count)
        var interpolatedFilterTypes = Array(repeating: EQBandFilterType.parametric, count: count)
        if oldCount == 1 {
            interpolatedGains = Array(repeating: oldGains.first ?? 0, count: count)
            interpolatedFilterTypes = Array(repeating: oldFilterTypes.first ?? .parametric, count: count)
        } else {
            for j in 0..<count {
                let position = Float(j) * Float(oldCount - 1) / Float(max(count - 1, 1))
                let low = Int(floor(position))
                let high = min(low + 1, oldCount - 1)
                let frac = position - Float(low)
                let lowVal = (low >= 0 && low < oldGains.count) ? oldGains[low] : 0
                let highVal = (high >= 0 && high < oldGains.count) ? oldGains[high] : lowVal
                interpolatedGains[j] = lowVal * (1 - frac) + highVal * frac
                interpolatedFilterTypes[j] = (low >= 0 && low < oldFilterTypes.count) ? oldFilterTypes[low] : .parametric
            }
        }

        // Apply interpolated gains to new EQ bands
        for (idx, gain) in interpolatedGains.enumerated() {
            if idx < newEQ.bands.count {
                newEQ.bands[idx].gain = gain
                newEQ.bands[idx].filterType = eqFilterType(for: interpolatedFilterTypes[idx])
            }
        }

        engine.disconnectNodeOutput(eqNode)
        engine.disconnectNodeInput(eqNode)

        if let inputGainNode {
            engine.connect(inputGainNode, to: newEQ, format: nil)
        } else {
            engine.connect(playerNode, to: newEQ, format: nil)
        }
        engine.connect(newEQ, to: crossoverPlugin.node, format: nil)

        // Swap references
        let previousEQ = eqNode
        eqNode = newEQ
        bandCount = count
        bandFrequencies = newFrequencies
        bandGains = interpolatedGains
        bandFilterTypes = interpolatedFilterTypes

        engine.disconnectNodeOutput(previousEQ)
        engine.disconnectNodeInput(previousEQ)
        engine.detach(previousEQ)
        startEngine()
        if audioFile != nil {
            schedulePlayback(from: currentFrame)
            if wasPlaying {
                playerNode.play()
                isPlaying = true
                startProgressTimer()
                if eightDAudioEnabled {
                    startEightDRotation()
                }
            } else {
                isPlaying = false
            }
        }
    }

    func setBandGain(index: Int, value: Float) {
        guard index >= 0 && index < eqNode.bands.count else { return }
        guard !bandGains.indices.contains(index) || abs(bandGains[index] - value) > 0.001 else { return }
        eqNode.bands[index].gain = value
        if index < bandGains.count { bandGains[index] = value }
    }

    func setBandFrequency(index: Int, value: Float) {
        guard index >= 0 && index < eqNode.bands.count else { return }
        let lowerBound = index > 0 ? bandFrequencies[index - 1] * 1.08 : 35
        let upperBound = index + 1 < bandFrequencies.count ? bandFrequencies[index + 1] / 1.08 : 18_000
        let clampedFrequency = min(max(value, lowerBound), upperBound)
        eqNode.bands[index].frequency = clampedFrequency
        if index < bandFrequencies.count {
            bandFrequencies[index] = clampedFrequency
        }
    }

    func setBandFilterType(index: Int, type: EQBandFilterType) {
        guard index >= 0 && index < eqNode.bands.count else { return }
        guard !bandFilterTypes.indices.contains(index) || bandFilterTypes[index] != type else { return }
        let band = eqNode.bands[index]
        band.filterType = eqFilterType(for: type)
        switch type {
        case .notch:
            band.bandwidth = 0.12
            band.gain = min(band.gain, -18)
            if index < bandGains.count { bandGains[index] = band.gain }
        case .highPass, .lowPass:
            band.bandwidth = 0.35
            band.gain = 0
            if index < bandGains.count { bandGains[index] = 0 }
        case .lowShelf, .highShelf:
            band.bandwidth = 0.7
            if abs(band.gain) < 0.5 {
                band.gain = 4
                if index < bandGains.count { bandGains[index] = 4 }
            }
        case .parametric:
            band.bandwidth = 0.5
        }
        if index < bandFilterTypes.count {
            bandFilterTypes[index] = type
        }
    }

    func applyGains(_ gains: [Float]) {
        let clampedGains = Array(gains.prefix(eqNode.bands.count))
        for (index, value) in clampedGains.enumerated() {
            eqNode.bands[index].gain = value
        }
        bandGains = clampedGains
    }

    func applyFilterTypes(_ filterTypes: [EQBandFilterType]) {
        var updatedTypes = Array(filterTypes.prefix(eqNode.bands.count))
        var updatedGains = bandGains

        for (index, type) in updatedTypes.enumerated() {
            let band = eqNode.bands[index]
            band.filterType = eqFilterType(for: type)
            switch type {
            case .notch:
                band.bandwidth = 0.12
                band.gain = min(band.gain, -18)
                if updatedGains.indices.contains(index) { updatedGains[index] = band.gain }
            case .highPass, .lowPass:
                band.bandwidth = 0.35
                band.gain = 0
                if updatedGains.indices.contains(index) { updatedGains[index] = 0 }
            case .lowShelf, .highShelf:
                band.bandwidth = 0.7
                if abs(band.gain) < 0.5 {
                    band.gain = 4
                    if updatedGains.indices.contains(index) { updatedGains[index] = 4 }
                }
            case .parametric:
                band.bandwidth = 0.5
            }
        }

        if updatedTypes.count < bandCount {
            updatedTypes += Array(repeating: .parametric, count: bandCount - updatedTypes.count)
        }
        bandFilterTypes = updatedTypes
        bandGains = updatedGains
    }

    func applyEffects(_ effects: PresetEffectSettings) {
        setIfChanged(\.bassBoostEnabled, effects.bassBoostEnabled)
        setIfChanged(\.bassBoostIntensity, effects.bassBoostIntensity)
        setIfChanged(\.bassBoostFrequency, effects.bassBoostFrequency)
        setIfChanged(\.virtualSubwooferEnabled, effects.virtualSubwooferEnabled)
        setIfChanged(\.virtualSubwooferMix, effects.virtualSubwooferMix)
        setIfChanged(\.virtualSubwooferCutoff, effects.virtualSubwooferCutoff)
        setIfChanged(\.cabinNotchEnabled, effects.cabinNotchEnabled)
        setIfChanged(\.cabinNotchFrequency, effects.cabinNotchFrequency)
        setIfChanged(\.cabinNotchQ, effects.cabinNotchQ)
        setIfChanged(\.cabinNotchGain, effects.cabinNotchGain)
        setIfChanged(\.adaptiveBassBoostEnabled, effects.adaptiveBassBoostEnabled)
        setIfChanged(\.crossoverEnabled, effects.crossoverEnabled)
        setIfChanged(\.crossoverFrequency, effects.crossoverFrequency)
        setIfChanged(\.crossoverMode, effects.crossoverMode)
        setIfChanged(\.subwooferPhaseInverted, effects.subwooferPhaseInverted)
        setIfChanged(\.smartLoudBassMode, effects.smartLoudBassMode)
        setIfChanged(\.subBassGain, effects.subBassGain)
        setIfChanged(\.punchBassGain, effects.punchBassGain)
        setIfChanged(\.warmthGain, effects.warmthGain)
        setIfChanged(\.bassTightness, effects.bassTightness)
        setIfChanged(\.subwooferModeEnabled, effects.subwooferModeEnabled)
        setIfChanged(\.bassMonoBelow100Enabled, effects.bassMonoBelow100Enabled)
        setIfChanged(\.trebleBoostEnabled, effects.trebleBoostEnabled)
        setIfChanged(\.loudnessEnabled, effects.loudnessEnabled)
        setIfChanged(\.compressorEnabled, effects.compressorEnabled)
        setIfChanged(\.compressorThreshold, effects.compressorThreshold)
        setIfChanged(\.compressorRatio, effects.compressorRatio)
        setIfChanged(\.compressorAttack, effects.compressorAttack)
        setIfChanged(\.compressorRelease, effects.compressorRelease)
        setIfChanged(\.limiterEnabled, effects.limiterEnabled)
        setIfChanged(\.limiterCeiling, effects.limiterCeiling)
        setIfChanged(\.limiterRelease, effects.limiterRelease)
        setIfChanged(\.stereoWideningEnabled, effects.stereoWideningEnabled)
        setIfChanged(\.stereoWideningIntensity, effects.stereoWideningIntensity)
        setIfChanged(\.spatialAudioEnabled, effects.spatialAudioEnabled)
        setIfChanged(\.spatialAudioDepth, effects.spatialAudioDepth)
        setIfChanged(\.surroundEnabled, effects.surroundEnabled)
        setIfChanged(\.surroundAmount, effects.surroundAmount)
        setIfChanged(\.eightDAudioEnabled, effects.eightDAudioEnabled)
        setIfChanged(\.eightDAudioIntensity, effects.eightDAudioIntensity)
        setIfChanged(\.eightDAudioSpeed, effects.eightDAudioSpeed)
        setIfChanged(\.eightDAudioMode, effects.eightDAudioMode)
        setIfChanged(\.softClipperEnabled, effects.softClipperEnabled)
        setIfChanged(\.inputGain, effects.inputGain)
        setIfChanged(\.outputGain, effects.outputGain)
        setVolumeBoost(effects.volumeBoost)
        setIfChanged(\.auxSignalBoostEnabled, effects.auxSignalBoostEnabled)
        setIfChanged(\.auxSignalBoostDB, effects.auxSignalBoostDB)
        setIfChanged(\.fmExciterEnabled, effects.fmExciterEnabled)
        setIfChanged(\.fmExciterIntensity, effects.fmExciterIntensity)
        setIfChanged(\.groundLoopSuppressorEnabled, effects.groundLoopSuppressorEnabled)
        setIfChanged(\.groundLoopHumFrequency, effects.groundLoopHumFrequency)
        setIfChanged(\.engineNoiseNotchEnabled, effects.engineNoiseNotchEnabled)
        setIfChanged(\.engineNoiseFrequency, effects.engineNoiseFrequency)
        setIfChanged(\.stereoCollapseEnabled, effects.stereoCollapseEnabled)
        setIfChanged(\.stereoCollapseWidth, effects.stereoCollapseWidth)
        setIfChanged(\.clipperProtectionEnabled, effects.clipperProtectionEnabled)
        setIfChanged(\.logic7SpatializerEnabled, effects.logic7SpatializerEnabled)
        setIfChanged(\.logic7Ambience, effects.logic7Ambience)
        setIfChanged(\.logic7CenterFocus, effects.logic7CenterFocus)
        setIfChanged(\.multibandCompressorEnabled, effects.multibandCompressorEnabled)
        setIfChanged(\.reverbAmount, effects.reverbAmount)
        setIfChanged(\.reverbSize, effects.reverbSize)
        setIfChanged(\.reverbDamping, effects.reverbDamping)
        if safeLoudModeEnabled {
            applySafeLoudMode()
        }
    }

    private func setIfChanged<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<AudioEngineManager, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    func currentEffectSettings() -> PresetEffectSettings {
        PresetEffectSettings(
            bassBoostEnabled: bassBoostEnabled,
            trebleBoostEnabled: trebleBoostEnabled,
            loudnessEnabled: loudnessEnabled,
            bassBoostIntensity: bassBoostIntensity,
            bassBoostFrequency: bassBoostFrequency,
            virtualSubwooferEnabled: virtualSubwooferEnabled,
            virtualSubwooferMix: virtualSubwooferMix,
            virtualSubwooferCutoff: virtualSubwooferCutoff,
            cabinNotchEnabled: cabinNotchEnabled,
            cabinNotchFrequency: cabinNotchFrequency,
            cabinNotchQ: cabinNotchQ,
            cabinNotchGain: cabinNotchGain,
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
            eightDAudioMode: eightDAudioMode,
            softClipperEnabled: softClipperEnabled,
            reverbAmount: reverbAmount,
            reverbSize: reverbSize,
            reverbDamping: reverbDamping,
            inputGain: inputGain,
            outputGain: outputGain,
            volumeBoost: volumeBoost,
            auxSignalBoostEnabled: auxSignalBoostEnabled,
            auxSignalBoostDB: auxSignalBoostDB,
            fmExciterEnabled: fmExciterEnabled,
            fmExciterIntensity: fmExciterIntensity,
            groundLoopSuppressorEnabled: groundLoopSuppressorEnabled,
            groundLoopHumFrequency: groundLoopHumFrequency,
            engineNoiseNotchEnabled: engineNoiseNotchEnabled,
            engineNoiseFrequency: engineNoiseFrequency,
            stereoCollapseEnabled: stereoCollapseEnabled,
            stereoCollapseWidth: stereoCollapseWidth,
            clipperProtectionEnabled: clipperProtectionEnabled,
            logic7SpatializerEnabled: logic7SpatializerEnabled,
            logic7Ambience: logic7Ambience,
            logic7CenterFocus: logic7CenterFocus,
            multibandCompressorEnabled: multibandCompressorEnabled,
            adaptiveBassBoostEnabled: adaptiveBassBoostEnabled,
            crossoverEnabled: crossoverEnabled,
            crossoverFrequency: crossoverFrequency,
            crossoverMode: crossoverMode,
            subwooferPhaseInverted: subwooferPhaseInverted,
            smartLoudBassMode: smartLoudBassMode,
            subBassGain: subBassGain,
            punchBassGain: punchBassGain,
            warmthGain: warmthGain,
            bassTightness: bassTightness,
            subwooferModeEnabled: subwooferModeEnabled,
            bassMonoBelow100Enabled: bassMonoBelow100Enabled
        )
    }

    func applySmartLoudBassMode(_ mode: SmartLoudBassMode) {
        smartLoudBassMode = mode
        isBatchingBassLabChanges = true
        defer {
            isBatchingBassLabChanges = false
            applyBassTightness()
            applyBassLabEQ()
        }
        safeLoudModeEnabled = mode != .clean
        limiterEnabled = true
        loudnessEnabled = mode != .clean
        adaptiveBassBoostEnabled = mode != .clean
        bassBoostEnabled = mode != .clean
        compressorEnabled = mode != .clean
        multibandCompressorEnabled = mode == .bassHeavy || mode == .max
        softClipperEnabled = mode == .bassHeavy || mode == .max
        stereoWideningEnabled = mode != .clean

        switch mode {
        case .clean:
            inputGain = 0.92
            outputGain = 0.92
            setVolumeBoost(1)
            bassBoostIntensity = 0
            compressorThreshold = -16
            compressorRatio = 2.2
            limiterCeiling = -1
            stereoWideningIntensity = 0.35
        case .loud:
            inputGain = 0.86
            outputGain = 0.88
            setVolumeBoost(1.18)
            bassBoostIntensity = 4
            bassBoostFrequency = 80
            compressorThreshold = -20
            compressorRatio = 3.2
            limiterCeiling = -2
            stereoWideningIntensity = 0.55
        case .bassHeavy:
            inputGain = 0.78
            outputGain = 0.84
            setVolumeBoost(1.28)
            bassBoostIntensity = 7
            bassBoostFrequency = 72
            compressorThreshold = -24
            compressorRatio = 4.2
            limiterCeiling = -3
            stereoWideningIntensity = 0.62
            subBassGain = max(subBassGain, 4)
            punchBassGain = max(punchBassGain, 3)
            warmthGain = max(warmthGain, 1.5)
        case .max:
            inputGain = 0.70
            outputGain = 0.78
            setVolumeBoost(1.35)
            bassBoostIntensity = 9
            bassBoostFrequency = 68
            compressorThreshold = -28
            compressorRatio = 5.5
            limiterCeiling = -4
            limiterRelease = min(limiterRelease, 0.05)
            stereoWideningIntensity = 0.70
            subBassGain = max(subBassGain, 5)
            punchBassGain = max(punchBassGain, 4)
            warmthGain = max(warmthGain, 2)
        }
    }

    func prepareBassLab() {
        if bandCount < 10 {
            setBandCount(10)
        }
        applyBassLabEQ()
    }

    func setVolumeBoost(_ value: Float) {
        let upperLimit: Float = safeLoudModeEnabled ? 1.35 : 3
        volumeBoost = min(Self.clampedVolumeBoost(value), upperLimit)
    }

    func resetAllEffects() {
        applyGains(Array(repeating: 0, count: bandCount))
        applyFilterTypes(Array(repeating: .parametric, count: bandCount))
        applyEffects(PresetEffectSettings(limiterEnabled: true))
    }

    func applyLegacyCarProfile(_ profile: LegacyCarAudioProfile) {
        if profile.bandCount != bandCount {
            setBandCount(profile.bandCount)
        }
        applyGains(profile.gains)
        applyFilterTypes(profile.filterTypes)
        applyEffects(profile.effects)
    }

    func currentTrackPresetSnapshot() -> TrackPresetSnapshot {
        let points = zip(zip(bandFrequencies, bandGains), bandFilterTypes).map { frequencyAndGain, filterType in
            PresetPoint(frequency: frequencyAndGain.0, gain: frequencyAndGain.1, filterType: filterType)
        }
        return TrackPresetSnapshot(
            bandCount: bandCount,
            points: points,
            effects: currentEffectSettings()
        )
    }

    func applyTrackPresetSnapshot(_ snapshot: TrackPresetSnapshot) {
        if snapshot.bandCount != bandCount {
            setBandCount(snapshot.bandCount)
        }
        let gains = bandFrequencies.map { frequency in
            snapshot.points.min { first, second in
                abs(log10(first.frequency) - log10(frequency)) < abs(log10(second.frequency) - log10(frequency))
            }?.gain ?? 0
        }
        let filterTypes = bandFrequencies.map { frequency in
            snapshot.points.min { first, second in
                abs(log10(first.frequency) - log10(frequency)) < abs(log10(second.frequency) - log10(frequency))
            }?.filterType ?? .parametric
        }
        applyGains(gains)
        applyFilterTypes(filterTypes)
        applyEffects(snapshot.effects)
    }

    private func applyBassLabEQ() {
        setNearestBandGain(targetFrequency: 45, value: subBassGain)
        setNearestBandGain(targetFrequency: 90, value: punchBassGain)
        setNearestBandGain(targetFrequency: 180, value: warmthGain)
        if subBassGain > 0 || punchBassGain > 0 {
            bassBoostEnabled = true
            bassBoostFrequency = punchBassGain >= subBassGain ? 85 : 55
            bassBoostIntensity = min(max(subBassGain * 0.9 + punchBassGain * 0.45, 0), 12)
        }
    }

    private func applyBassTightness() {
        let clamped = min(max(bassTightness, 0), 1)
        compressorAttack = 0.030 - clamped * 0.024
        compressorRelease = 0.280 - clamped * 0.180
        if clamped > 0.55 {
            compressorEnabled = true
            multibandCompressorEnabled = true
        }
    }

    private func setNearestBandGain(targetFrequency: Float, value: Float) {
        guard let index = bandFrequencies.indices.min(by: {
            abs(log10(bandFrequencies[$0]) - log10(targetFrequency)) < abs(log10(bandFrequencies[$1]) - log10(targetFrequency))
        }) else { return }
        setBandFilterType(index: index, type: targetFrequency <= 60 ? .lowShelf : .parametric)
        setBandGain(index: index, value: min(max(value, -12), 12))
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
            waveformSamples = waveformHint?.isEmpty == false ? waveformHint ?? [] : []

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
                let now = Date()
                if now.timeIntervalSince(manager.lastNowPlayingRefresh) >= 1 {
                    manager.lastNowPlayingRefresh = now
                    manager.updateNowPlayingElapsedTime()
                }
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
        eightDAudioPosition = 0
        eightDEnergyEnvelope = 0
        eightDPreviousBassEnergy = 0
        outputGainNode?.pan = 0
    }

    private func updateEightDPosition() {
        guard eightDAudioEnabled else { return }
        let clampedIntensity = min(max(eightDAudioIntensity, 0), 1)
        let clampedSpeed = min(max(eightDAudioSpeed, 0.03), 0.75)

        let bassEnergy = averageSpectrumLevel(in: 0..<min(6, spectrumLevels.count))
        let vocalEnergy = averageSpectrumLevel(in: min(6, spectrumLevels.count)..<min(14, spectrumLevels.count))
        let airEnergy = averageSpectrumLevel(in: min(14, spectrumLevels.count)..<spectrumLevels.count)
        let levelEnergy = min(max(currentLevel * 4, 0), 1)
        let bassTransient = max(0, bassEnergy - eightDPreviousBassEnergy)
        eightDPreviousBassEnergy += (bassEnergy - eightDPreviousBassEnergy) * 0.32
        let sourceEnergy = min(max(levelEnergy * 0.25 + bassEnergy * 0.35 + vocalEnergy * 0.25 + airEnergy * 0.15, 0), 1)
        eightDEnergyEnvelope += (sourceEnergy - eightDEnergyEnvelope) * 0.18
        let modeEnergy: Float
        let spectralTilt: Float
        let radiusBias: Float
        let depthBias: Float
        let centerPull: Float

        switch eightDAudioMode {
        case .beatReactive:
            modeEnergy = min(max(eightDEnergyEnvelope * 0.40 + bassEnergy * 0.35 + bassTransient * 2.1, 0), 1)
            spectralTilt = min(max((airEnergy - bassEnergy) * 0.55, -0.22), 0.22)
            radiusBias = bassEnergy
            depthBias = bassEnergy
            centerPull = 0
        case .vocalCenter:
            modeEnergy = min(max(eightDEnergyEnvelope * 0.25 + vocalEnergy * 0.62 + bassTransient * 0.8, 0), 1)
            spectralTilt = min(max((airEnergy - bassEnergy) * 0.24, -0.12), 0.12)
            radiusBias = 1 - vocalEnergy * 0.45
            depthBias = vocalEnergy * 0.35
            centerPull = vocalEnergy * 0.62
        case .bassOrbit:
            modeEnergy = min(max(bassEnergy * 0.62 + bassTransient * 2.4 + eightDEnergyEnvelope * 0.18, 0), 1)
            spectralTilt = min(max((bassEnergy - airEnergy) * 0.32, -0.18), 0.18)
            radiusBias = bassEnergy * 1.25
            depthBias = bassEnergy * 1.15
            centerPull = 0
        case .wideAir:
            modeEnergy = min(max(airEnergy * 0.58 + vocalEnergy * 0.20 + eightDEnergyEnvelope * 0.22, 0), 1)
            spectralTilt = min(max((airEnergy - vocalEnergy) * 0.58, -0.25), 0.25)
            radiusBias = airEnergy
            depthBias = airEnergy * 0.45
            centerPull = vocalEnergy * 0.18
        }

        let radius = 0.7 + clampedIntensity * (1.25 + modeEnergy * 1.45 + radiusBias * 0.8)
        let depth = -1.0 - clampedIntensity * (1.0 + depthBias * 1.2)
        let angleStep = clampedSpeed * (modeEnergy * 0.13 + bassTransient * 0.65)

        eightDRotationAngle += angleStep
        let motionScale = (0.10 + modeEnergy * 0.90) * (1 - centerPull)
        let x = (sin(eightDRotationAngle) * radius * motionScale) + spectralTilt
        let z = depth + cos(eightDRotationAngle) * radius * (0.20 + modeEnergy * 0.35)
        environmentNode?.position = AVAudioMake3DPoint(x, 0, z)

        // AVAudioEnvironmentNode spatializes mono sources best. Most imported songs are stereo,
        // so pan automation is the guaranteed audible 8D movement for regular MP3 files.
        let targetPan = sin(eightDRotationAngle) * min(0.95, clampedIntensity) * motionScale + spectralTilt
        eightDPan += (min(max(targetPan, -0.95), 0.95) - eightDPan) * (0.08 + modeEnergy * 0.20)
        eightDAudioPosition = eightDPan
        updateOutputPan()
    }

    private func averageSpectrumLevel(in range: Range<Int>) -> Float {
        guard !range.isEmpty, !spectrumLevels.isEmpty else { return 0 }
        let values = range.compactMap { index -> Float? in
            guard spectrumLevels.indices.contains(index) else { return nil }
            return spectrumLevels[index]
        }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Float(values.count)
    }

    private func updateOutputPan() {
        // combine base stereo balance and eightD pan
        let combined = min(max(stereoBalance + eightDPan, -1), 1)
        outputGainNode?.pan = combined
    }

    func startLevelMetering() {
        guard !isLevelMeteringActive else { return }
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        var lastTapUpdate = Date.distantPast
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            let now = Date()
            guard now.timeIntervalSince(lastTapUpdate) >= 0.18 else { return }
            lastTapUpdate = now
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
            Task { @MainActor in self?.updateMeters(with: samples, now: now) }
        }
        isLevelMeteringActive = true
        startAdaptiveBassTimerIfNeeded()
    }

    func stopLevelMetering() {
        guard isLevelMeteringActive else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        isLevelMeteringActive = false
        currentLevel = 0
        inputPeak = 0
        outputPeak = 0
        rmsLevel = 0
        lufsApprox = -70
        dynamicRange = 0
        gainReduction = 0
        limiterActive = false
        clippingRisk = 0
        spectrumLevels = Array(repeating: 0, count: spectrumBandCount)
        stopAdaptiveBassTimer()
    }

    private func startAdaptiveBassTimerIfNeeded() {
        guard adaptiveBassBoostEnabled else { return }
        adaptiveTimer?.invalidate()
        adaptiveTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            let manager = self
            Task { @MainActor in manager?.performAdaptiveBassStep() }
        }
    }

    private func stopAdaptiveBassTimer() {
        adaptiveTimer?.invalidate()
        adaptiveTimer = nil
        // restore plugin gain to intensity if adaptive disabled
        if !adaptiveBassBoostEnabled {
            bassBoostPlugin.intensity = bassBoostIntensity
            adaptiveCurrentGain = bassBoostPlugin.intensity
        }
    }

    private func performAdaptiveBassStep() {
        guard adaptiveBassBoostEnabled else { return }
        // determine target reduction based on overload/currentLevel
        let overloaded = isOverloaded
        let level = currentLevel
        // if overloaded or level high, reduce to 40% of intensity
        let targetMultiplier: Float = (overloaded || level >= 0.6) ? 0.4 : 1.0
        adaptiveTargetGain = bassBoostIntensity * targetMultiplier

        // exponential smoothing towards target
        let attack: Float = 0.2
        let release: Float = 0.05
        let dt: Float = 0.08
        let coeff: Float = adaptiveTargetGain > adaptiveCurrentGain ? (1 - exp(-dt / attack)) : (1 - exp(-dt / release))
        adaptiveCurrentGain = adaptiveCurrentGain + coeff * (adaptiveTargetGain - adaptiveCurrentGain)
        bassBoostPlugin.intensity = adaptiveCurrentGain
    }

    private func updateMeters(with samples: [Float], now: Date) {
        guard !samples.isEmpty else { return }
        guard now.timeIntervalSince(lastMeterUpdate) >= 0.16 else { return }
        lastMeterUpdate = now

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        let protectedOutputGain = max(outputGain, 0.05)
        let protectedBoost = max(volumeBoost, 0.05)
        let estimatedInputPeak = min(1.5, peak / (protectedOutputGain * protectedBoost))
        let peakDB = Self.decibels(fromLinear: peak)
        let rmsDB = Self.decibels(fromLinear: rms)

        currentLevel = rms
        rmsLevel = rms
        outputPeak = peak
        inputPeak = estimatedInputPeak
        overloadPeak = peak
        lufsApprox = rmsDB - 1.5
        dynamicRange = max(0, peakDB - rmsDB)
        limiterActive = limiterEnabled && (peakDB >= limiterCeiling - 0.7 || rms > 0.46)
        gainReduction = limiterActive ? max(0, peakDB - limiterCeiling) : 0
        clippingRisk = min(max((peak - 0.84) / 0.16, rms > 0.70 ? 0.65 : 0), 1)
        isOverloaded = peak >= 0.98 || rms >= 0.78
        spectrumLevels = calculateSpectrumLevels(from: samples)
        applyClippingGuardIfNeeded(now: now)
    }

    private func applyClippingGuardIfNeeded(now: Date) {
        guard safeLoudModeEnabled || smartLoudBassMode != .clean else { return }
        guard clippingRisk > 0.72 || isOverloaded else { return }
        guard now.timeIntervalSince(lastClippingGuardUpdate) >= 0.7 else { return }
        lastClippingGuardUpdate = now

        limiterEnabled = true
        limiterCeiling = max(-8, limiterCeiling - 0.5)
        limiterRelease = max(0.025, limiterRelease * 0.88)
        if outputGain > 0.62 {
            outputGain = max(0.62, outputGain - 0.03)
        } else {
            inputGain = max(0.58, inputGain - 0.025)
        }
        if volumeBoost > 1.12 {
            setVolumeBoost(volumeBoost - 0.04)
        }
    }

    private static func decibels(fromLinear value: Float) -> Float {
        20 * log10(max(value, 0.000_001))
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

/// Fine-grained observation keeps meter ticks out of the root navigation and library.
@MainActor
@Observable
final class AudioTelemetry {
    var currentLevel: Float = 0
    var overloadPeak: Float = 0
    var inputPeak: Float = 0
    var outputPeak: Float = 0
    var rmsLevel: Float = 0
    var lufsApprox: Float = -70
    var dynamicRange: Float = 0
    var gainReduction: Float = 0
    var limiterActive: Bool = false
    var clippingRisk: Float = 0
    var isOverloaded: Bool = false
    var spectrumLevels: [Float] = Array(repeating: 0, count: 16)
    var eightDAudioPosition: Float = 0
    var currentTime: Double = 0
}
