import AVFoundation
import Observation
import os

nonisolated private final class AudioIngest: @unchecked Sendable {
    private static let sampleRate = 16000.0
    private static let converterSlackFrames: AVAudioFrameCount = 32
    private static let samplesPerChunk = 16000

    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
    private let continuation: AsyncStream<[Float]>.Continuation
    private var converter: AVAudioConverter?
    private var carry = [Float]()

    init(continuation: AsyncStream<[Float]>.Continuation) {
        self.continuation = continuation
    }

    func receive(_ buffer: AVAudioPCMBuffer) {
        if converter == nil { converter = AVAudioConverter(from: buffer.format, to: target) }
        guard let converter else { return }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * Self.sampleRate / buffer.format.sampleRate) + Self.converterSlackFrames
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
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
        carry.append(contentsOf: UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength)))
        while carry.count >= Self.samplesPerChunk {
            continuation.yield(Array(carry.prefix(Self.samplesPerChunk)))
            carry.removeFirst(Self.samplesPerChunk)
        }
    }
}

@Observable
final class Captioner {
    private static let logger = Logger(subsystem: "com.kirill.givemesub", category: "captioner")

    var isRunning = false
    var language: String?
    var lastText = ""
    @ObservationIgnored private let whistle = Whistle()
    @ObservationIgnored private let overlay = CaptionOverlay()
    @ObservationIgnored private let tap = SystemAudioTap()
    @ObservationIgnored private var session: Task<Void, Never>?
    @ObservationIgnored private var chunkSink: AsyncStream<[Float]>.Continuation?
    @ObservationIgnored private var loaded = false

    func toggle() { isRunning ? stop() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        session = Task { await run() }
    }

    func stop() {
        session?.cancel()
        tap.stop()
        chunkSink?.finish()
        chunkSink = nil
        isRunning = false
        overlay.flash("Captions off")
    }

    private func run() async {
        do {
            if !loaded {
                let modelURL = Bundle.main.url(forResource: "whistle", withExtension: "cact")!
                try await whistle.load(modelURL: modelURL)
                loaded = true
            }
            guard !Task.isCancelled else { return }
            let (chunks, sink) = AsyncStream.makeStream(of: [Float].self)
            chunkSink = sink
            try tap.start(onBuffer: AudioIngest(continuation: sink).receive)
            overlay.flash("Captions on")
            for await chunk in chunks {
                do {
                    publish(try await whistle.process(chunk, language: language))
                } catch {
                    Self.logger.error("transcription pass failed: \(error)")
                }
            }
            let tail = try await whistle.finish()
            guard !Task.isCancelled else { return }
            publish(tail)
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.error("captioning failed: \(error)")
            tap.stop()
            isRunning = false
        }
    }

    private func publish(_ segment: WhistleSegment) {
        guard !segment.text.isEmpty || !segment.pending.isEmpty else { return }
        lastText = segment.text
        overlay.show(text: segment.text, pending: segment.pending)
    }
}
