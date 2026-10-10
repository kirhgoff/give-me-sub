import Observation
import os

@Observable
final class Captioner {
    static let captionsOn = "Captions on"
    static let captionsOff = "Captions off"
    static let captionsUnavailable = "Captions unavailable"

    private static let logger = Logger(subsystem: "com.kirill.givemesub", category: "captioner")

    private(set) var isRunning = false
    var language: Language?
    private(set) var lastText = ""
    let caption: CaptionState

    private let source: any AudioSource
    private let transcriber: any Transcriber
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var flushTask: Task<Void, Never>?

    init(source: any AudioSource = SystemAudioTap(), transcriber: any Transcriber = Whistle(), caption: CaptionState = CaptionState()) {
        self.source = source
        self.transcriber = transcriber
        self.caption = caption
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    @discardableResult
    func start() -> Task<Void, Never> {
        if isRunning, let sessionTask { return sessionTask }
        isRunning = true
        let previousFlush = flushTask
        let task = Task { await run(after: previousFlush) }
        sessionTask = task
        return task
    }

    @discardableResult
    func stop() -> Task<Void, Never> {
        guard isRunning else { return flushTask ?? Task {} }
        isRunning = false
        source.stop()
        sessionTask?.cancel()
        caption.flash(Self.captionsOff)
        let task = Task { await flush() }
        flushTask = task
        return task
    }

    private func run(after previousFlush: Task<Void, Never>?) async {
        await previousFlush?.value
        let blocks: AsyncStream<[Float]>
        do {
            try await transcriber.prepare()
            guard !Task.isCancelled else { return }
            blocks = try source.start()
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.error("captioning failed to start: \(error)")
            isRunning = false
            caption.flash(Self.captionsUnavailable)
            return
        }
        caption.flash(Self.captionsOn)
        var chunker = SampleChunker()
        for await block in blocks {
            for chunk in chunker.append(block) {
                await transcribe(chunk)
            }
        }
        guard !Task.isCancelled else { return }
        await stop().value
    }

    private func transcribe(_ chunk: [Float]) async {
        guard !Task.isCancelled else { return }
        do {
            let segment = try await transcriber.process(chunk, language: language)
            guard !Task.isCancelled, let segment else { return }
            lastText = segment.text
            caption.show(segment)
        } catch {
            Self.logger.error("transcription pass failed: \(error)")
        }
    }

    private func flush() async {
        do {
            guard let tail = try await transcriber.finish() else { return }
            lastText = tail.text
        } catch {
            Self.logger.error("transcription flush failed: \(error)")
        }
    }
}
