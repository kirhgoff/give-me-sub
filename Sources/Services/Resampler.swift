import AVFoundation

// confined to the tap's IO queue
nonisolated final class Resampler: @unchecked Sendable {
    private static let converterSlackFrames: AVAudioFrameCount = 32

    private let converter: AVAudioConverter
    private let target: AVAudioFormat

    init?(from format: AVAudioFormat) {
        guard
            let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: SpeechFormat.sampleRate, channels: 1, interleaved: false),
            let converter = AVAudioConverter(from: format, to: target)
        else { return nil }
        self.target = target
        self.converter = converter
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
        let ratio = SpeechFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + Self.converterSlackFrames
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity), let channel = out.floatChannelData else { return [] }
        var consumed = false
        converter.convert(to: out, error: nil) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
    }
}
