import CNeedle
import Foundation

nonisolated struct WhistleError: Error, CustomStringConvertible {
    let code: Int32
    let reason: String

    var description: String { "needle error \(code): \(reason)" }
}

actor Whistle: Transcriber {
    private static let outputCapacity = 1 << 16

    private let queue = DispatchSerialQueue(label: "givemesub.whistle")
    private let modelURL: URL
    private var out = [CChar](repeating: 0, count: Whistle.outputCapacity)
    private var isPrepared = false

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    init(modelURL: URL = Bundle.main.url(forResource: "whistle", withExtension: "cact")!) {
        self.modelURL = modelURL
    }

    func prepare() throws {
        guard !isPrepared else { return }
        let bytes = try Data(contentsOf: modelURL)
        let status = bytes.withUnsafeBytes { needle_load($0.bindMemory(to: UInt8.self).baseAddress, UInt64(bytes.count)) }
        try check(status)
        isPrepared = true
    }

    func process(_ chunk: [Float], language: Language?) throws -> TranscriptSegment? {
        let code = language?.rawValue
        let status = chunk.withUnsafeBufferPointer { needle_stream_transcribe_process($0.baseAddress, Int32(chunk.count), code, nil, &out, Int32(out.count)) }
        return try decode(status)
    }

    func finish() throws -> TranscriptSegment? {
        try decode(needle_stream_transcribe_stop(&out, Int32(out.count)))
    }

    private func check(_ status: Int32) throws {
        guard status >= 0 else { throw WhistleError(code: status, reason: String(cString: needle_last_error())) }
    }

    private func decode(_ status: Int32) throws -> TranscriptSegment? {
        try check(status)
        let segment = try JSONDecoder().decode(TranscriptSegment.self, from: Data(out.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }))
        return segment.text.isEmpty && segment.pending.isEmpty ? nil : segment
    }
}
