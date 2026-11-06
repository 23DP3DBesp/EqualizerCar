import AVFoundation

/// The Apple EQ does not advertise sample ramps. Coalesce UI targets without publishing intermediate values.
@MainActor
final class EQParameterSmoother {
    private struct Ramp {
        var value: Float
        var target: Float
        let logarithmic: Bool
        let apply: (Float) -> Void
    }
    private var ramps: [Int: Ramp] = [:]
    private var timer: Timer?

    func set(key: Int, current: Float, target: Float, logarithmic: Bool = false, apply: @escaping (Float) -> Void) {
        guard target.isFinite else { return }
        if var ramp = ramps[key] {
            ramp.target = target
            ramps[key] = ramp
        } else {
            ramps[key] = Ramp(value: current, target: target, logarithmic: logarithmic, apply: apply)
        }
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.step() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func cancelAll() { timer?.invalidate(); timer = nil; ramps.removeAll() }
    func cancel(key: Int) { ramps.removeValue(forKey: key) }

    private func step() {
        for key in Array(ramps.keys) {
            guard var ramp = ramps[key] else { continue }
            if ramp.logarithmic {
                ramp.value = exp(log(max(ramp.value, 1)) * 0.8 + log(max(ramp.target, 1)) * 0.2)
            } else { ramp.value += (ramp.target - ramp.value) * 0.2 }
            if abs(ramp.value - ramp.target) < (ramp.logarithmic ? 0.05 : 0.005) {
                ramp.apply(ramp.target); ramps.removeValue(forKey: key)
            } else {
                ramp.apply(ramp.value); ramps[key] = ramp
            }
        }
        if ramps.isEmpty { timer?.invalidate(); timer = nil }
    }
    deinit { timer?.invalidate() }
}
