import AVFoundation
import Foundation

struct WaveformAnalyzer {
    nonisolated static let defaultSampleCount = 240

    nonisolated static func samples(from url: URL, targetCount: Int = defaultSampleCount) -> [Float] {
        do {
            let file = try AVAudioFile(forReading: url)
            return samples(from: file, targetCount: targetCount)
        } catch {
            print("Ошибка расчёта waveform: \(error)")
            return emptySamples(count: targetCount)
        }
    }

    nonisolated static func samples(from file: AVAudioFile, targetCount: Int = defaultSampleCount) -> [Float] {
        let originalPosition = file.framePosition
        defer { file.framePosition = originalPosition }

        guard targetCount > 0, file.length > 0 else {
            return emptySamples(count: targetCount)
        }

        let bucketSize = max(Double(file.length) / Double(targetCount), 1)
        var peaks = Array(repeating: Float(0), count: targetCount)
        let bufferCapacity: AVAudioFrameCount = 8_192

        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: bufferCapacity) else {
            return emptySamples(count: targetCount)
        }

        do {
            file.framePosition = 0
            var globalFrame: AVAudioFramePosition = 0

            while globalFrame < file.length {
                try file.read(into: buffer, frameCount: bufferCapacity)
                let frameLength = Int(buffer.frameLength)
                guard frameLength > 0, let channelData = buffer.floatChannelData else { break }

                let channelCount = Int(buffer.format.channelCount)
                for frame in 0..<frameLength {
                    let bucket = min(Int(Double(globalFrame + AVAudioFramePosition(frame)) / bucketSize), targetCount - 1)
                    var peak: Float = 0

                    for channel in 0..<channelCount {
                        peak = max(peak, abs(channelData[channel][frame]))
                    }

                    peaks[bucket] = max(peaks[bucket], peak)
                }

                globalFrame += AVAudioFramePosition(frameLength)
            }
        } catch {
            print("Ошибка чтения аудио для waveform: \(error)")
            return emptySamples(count: targetCount)
        }

        let maxPeak = max(peaks.max() ?? 0, 0.000_001)
        return peaks.map { min(max($0 / maxPeak, 0), 1) }
    }

    nonisolated static func duration(from url: URL) -> Double {
        do {
            let file = try AVAudioFile(forReading: url)
            return Double(file.length) / file.processingFormat.sampleRate
        } catch {
            print("Ошибка чтения длительности трека: \(error)")
            return 0
        }
    }

    private nonisolated static func emptySamples(count: Int) -> [Float] {
        Array(repeating: 0, count: max(count, 0))
    }
}
