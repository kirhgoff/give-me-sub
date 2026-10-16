import Foundation
import Observation
import Testing
@testable import GiveMeSub

nonisolated struct ChunkingCase: Sendable {
    let blockSizes: [Int]
    let chunkCount: Int
}

private final class FakePreferenceStore: PreferenceStore {
    private var values = [String: Any]()

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }
}

nonisolated private struct FakeFailure: Error {}

private final class FakeAudioSource: AudioSource {
    private let failure: (any Error)?
    private let stream: AsyncStream<[Float]>
    private let continuation: AsyncStream<[Float]>.Continuation
    private(set) var stopCount = 0

    init(failure: (any Error)? = nil) {
        self.failure = failure
        (stream, continuation) = AsyncStream.makeStream(of: [Float].self)
    }

    func start() throws -> AsyncStream<[Float]> {
        if let failure { throw failure }
        return stream
    }

    func stop() {
        stopCount += 1
        continuation.finish()
    }

    func emit(blockSizes: [Int], level: Float = 0) {
        for size in blockSizes {
            continuation.yield([Float](repeating: level, count: size))
        }
    }

    func end() {
        continuation.finish()
    }
}

private actor FakeTranscriber: Transcriber {
    private var results = [Result<TranscriptSegment?, any Error>]()
    private var tail: TranscriptSegment?
    private(set) var chunks = [[Float]]()
    private(set) var languages = [Language?]()

    func script(_ results: [Result<TranscriptSegment?, any Error>], tail: TranscriptSegment? = nil) {
        self.results = results
        self.tail = tail
    }

    func prepare() {}

    func process(_ chunk: [Float], language: Language?) throws -> TranscriptSegment? {
        chunks.append(chunk)
        languages.append(language)
        guard !results.isEmpty else { return nil }
        return try results.removeFirst().get()
    }

    func finish() -> TranscriptSegment? {
        tail
    }
}

struct CaptionerTests {
    private let audible: Float = 0.5
    private let source = FakeAudioSource()
    private let transcriber = FakeTranscriber()
    private let caption = CaptionState()
    private let preferences = Preferences(store: FakePreferenceStore())
    private let captioner: Captioner

    init() {
        captioner = Captioner(source: source, transcriber: transcriber, caption: caption, preferences: preferences)
    }

    @Test
    func `stop leaves the captions-off flash over the flushed tail`() async {
        await transcriber.script([], tail: TranscriptSegment(text: "last words", pending: ""))
        let session = captioner.start()
        await waitForCommitted { $0 == Captioner.captionsOn }

        await captioner.stop().value
        await session.value

        #expect(caption.committed == Captioner.captionsOff)
        #expect(caption.pending.isEmpty)
        #expect(!captioner.isRunning)
    }

    @Test
    func `start flashes captions on and runs`() async {
        let session = captioner.start()
        await waitForCommitted { $0 == Captioner.captionsOn }

        #expect(captioner.isRunning)
        #expect(caption.isVisible)

        captioner.stop()
        await session.value
    }

    @Test(arguments: [
        ChunkingCase(blockSizes: Array(repeating: 4000, count: 8), chunkCount: 2),
        ChunkingCase(blockSizes: [10_000, 10_000, 10_000], chunkCount: 1),
        ChunkingCase(blockSizes: [16_000], chunkCount: 1),
        ChunkingCase(blockSizes: [15_999], chunkCount: 0),
    ])
    func `blocks are cut into whole one-second chunks`(_ chunking: ChunkingCase) async {
        source.emit(blockSizes: chunking.blockSizes)
        source.end()

        await captioner.start().value

        let sizes = await transcriber.chunks.map(\.count)
        #expect(sizes == Array(repeating: SpeechFormat.samplesPerChunk, count: chunking.chunkCount))
    }

    @Test(arguments: [Language.english, .german, nil])
    func `the selected language reaches the transcriber`(_ language: Language?) async {
        preferences.language = language
        source.emit(blockSizes: [SpeechFormat.samplesPerChunk])
        source.end()

        await captioner.start().value

        #expect(await transcriber.languages == [language])
    }

    @Test
    func `committed and pending text reach the caption`() async {
        await transcriber.script([
            .success(TranscriptSegment(text: "turn off", pending: "the")),
            .success(TranscriptSegment(text: "the lights", pending: "")),
        ])
        source.emit(blockSizes: [SpeechFormat.samplesPerChunk, SpeechFormat.samplesPerChunk])
        let session = captioner.start()

        await waitForCommitted { $0.hasSuffix("turn off the lights") }

        #expect(caption.pending.isEmpty)
        captioner.stop()
        await session.value
    }

    @Test
    func `subtitles mode shows whole sentences without pending`() async {
        preferences.captionMode = .subtitles
        await transcriber.script([.success(TranscriptSegment(text: "Hello there.", pending: "how are"))])
        source.emit(blockSizes: [SpeechFormat.samplesPerChunk])
        let session = captioner.start()

        await waitForCommitted { $0.hasSuffix("there.") }

        #expect(caption.committed == "Hello there.")
        #expect(caption.pending.isEmpty)
        captioner.stop()
        await session.value
    }

    @Test
    func `empty passes change nothing`() async {
        await transcriber.script([
            .success(TranscriptSegment(text: "hello", pending: "")),
            .success(nil),
            .success(TranscriptSegment(text: "world", pending: "")),
        ])
        source.emit(blockSizes: Array(repeating: SpeechFormat.samplesPerChunk, count: 3))
        let session = captioner.start()

        await waitForCommitted { $0.hasSuffix("world") }

        #expect(caption.committed.hasSuffix("hello world"))
        captioner.stop()
        await session.value
    }

    @Test
    func `the caption keeps only the last eighteen words`() async {
        let words = (1...20).map { "w\($0)" }
        await transcriber.script([.success(TranscriptSegment(text: words.joined(separator: " "), pending: ""))])
        source.emit(blockSizes: [SpeechFormat.samplesPerChunk])
        let session = captioner.start()

        await waitForCommitted { $0.hasSuffix("w20") }

        #expect(caption.committed == words.suffix(CaptionState.maxWords).joined(separator: " "))
        captioner.stop()
        await session.value
    }

    @Test
    func `a failing pass is skipped and the session continues`() async {
        await transcriber.script([.failure(FakeFailure()), .success(TranscriptSegment(text: "second", pending: ""))])
        source.emit(blockSizes: [SpeechFormat.samplesPerChunk, SpeechFormat.samplesPerChunk])
        let session = captioner.start()

        await waitForCommitted { $0.hasSuffix("second") }

        #expect(captioner.isRunning)
        captioner.stop()
        await session.value
    }

    @Test
    func `a source that ends on its own stops the session`() async {
        source.end()

        await captioner.start().value

        #expect(!captioner.isRunning)
        #expect(caption.committed == Captioner.captionsOff)
        #expect(source.stopCount == 1)
    }

    @Test
    func `a session that hears only silence stops itself`() async {
        source.emit(blockSizes: Array(repeating: SpeechFormat.samplesPerChunk, count: Captioner.silentChunksBeforeWarning))

        await captioner.start().value

        #expect(!captioner.isRunning)
        #expect(source.stopCount == 1)
        #expect(await transcriber.chunks.count == Captioner.silentChunksBeforeWarning - 1)
    }

    @Test
    func `the silence warning outlives the captions-off flash`() async {
        source.emit(blockSizes: Array(repeating: SpeechFormat.samplesPerChunk, count: Captioner.silentChunksBeforeWarning))

        await captioner.start().value

        #expect(caption.committed == Captioner.noSoundWarning)
        #expect(caption.pending.isEmpty)
        #expect(caption.isVisible)
    }

    @Test
    func `silence after sound is not a warning`() async {
        source.emit(blockSizes: [SpeechFormat.samplesPerChunk], level: audible)
        source.emit(blockSizes: Array(repeating: SpeechFormat.samplesPerChunk, count: Captioner.silentChunksBeforeWarning))
        source.end()

        await captioner.start().value

        #expect(caption.committed == Captioner.captionsOff)
        #expect(await transcriber.chunks.count == Captioner.silentChunksBeforeWarning + 1)
    }

    @Test
    func `a source that fails to start leaves captions unavailable`() async {
        let failing = Captioner(source: FakeAudioSource(failure: FakeFailure()), transcriber: transcriber, caption: caption, preferences: preferences)

        await failing.start().value

        #expect(!failing.isRunning)
        #expect(caption.committed == Captioner.captionsUnavailable)
        #expect(caption.isVisible)
    }

    private func waitForCommitted(_ matches: @escaping (String) -> Bool) async {
        for await committed in Observations({ [caption] in caption.committed }) where matches(committed) {
            return
        }
    }
}
