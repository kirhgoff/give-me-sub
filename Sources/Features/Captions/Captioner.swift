import Observation
import os

@Observable
final class Captioner {
    static let captionsOn = "Captions on"
    static let captionsOff = "Captions off"
    static let captionsUnavailable = "Captions unavailable"
    static let noSoundWarning = "No sound reaching GiveMeSub. Play something, or allow it in System Settings › Privacy & Security › Screen & System Audio Recording."
    static let silentChunksBeforeWarning = 10
    static let silenceAmplitude: Float = 0.001

    private static let logger = Logger(subsystem: "com.kirhgoff.givemesub", category: "captioner")

    private(set) var isRunning = false
    let caption: CaptionState

    private let source: any AudioSource
    private let transcriber: any Transcriber
    private let preferences: Preferences
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var flushTask: Task<Void, Never>?

    init(source: any AudioSource = SystemAudioTap(), transcriber: any Transcriber = Whistle(), caption: CaptionState = CaptionState(), preferences: Preferences = Preferences()) {
        self.source = source
        self.transcriber = transcriber
        self.caption = caption
        self.preferences = preferences
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
            Self.logger.error("captioning failed to start: \(error, privacy: .public)")
            isRunning = false
            caption.flash(Self.captionsUnavailable)
            return
        }
        caption.flash(Self.captionsOn)
        var chunker = SampleChunker()
        var chunkCount = 0
        var heardSound = false
        for await block in blocks {
            for chunk in chunker.append(block) {
                chunkCount += 1
                heardSound = heardSound || !Self.isSilent(chunk)
                if !heardSound, chunkCount >= Self.silentChunksBeforeWarning {
                    guard !Task.isCancelled else { return }
                    Self.logger.error("no sound in the first \(chunkCount) chunks; stopping")
                    let flush = stop()
                    caption.warn(Self.noSoundWarning)
                    await flush.value
                    return
                }
                await transcribe(chunk)
            }
        }
        guard !Task.isCancelled else { return }
        await stop().value
    }

    private func transcribe(_ chunk: [Float]) async {
        guard !Task.isCancelled else { return }
        do {
            let segment = try await transcriber.process(chunk, language: preferences.language)
            guard !Task.isCancelled, let segment else { return }
            switch preferences.captionMode {
            case .rolling: caption.show(segment)
            case .subtitles: caption.showSubtitle(segment.text)
            }
        } catch {
            Self.logger.error("transcription pass failed: \(error, privacy: .public)")
        }
    }

    private func flush() async {
        do {
            _ = try await transcriber.finish()
        } catch {
            Self.logger.error("transcription flush failed: \(error, privacy: .public)")
        }
    }

    private static func isSilent(_ chunk: [Float]) -> Bool {
        chunk.allSatisfy { abs($0) < silenceAmplitude }
    }
}
