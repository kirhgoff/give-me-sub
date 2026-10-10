import CNeedle
import Foundation

nonisolated struct WhistleSegment: Decodable, Sendable {
    let text: String
    let pending: String
    let received: Double
}

nonisolated struct WhistleError: Error, CustomStringConvertible {
    let code: Int32
    let reason: String

    var description: String { "needle error \(code): \(reason)" }
}

actor Whistle {
    private static let outputCapacity = 1 << 16

    private let queue = DispatchSerialQueue(label: "givemesub.whistle")
    private var out = [CChar](repeating: 0, count: Whistle.outputCapacity)

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    func load(modelURL: URL) throws {
        let bytes = try Data(contentsOf: modelURL)
        let status = bytes.withUnsafeBytes { needle_load($0.bindMemory(to: UInt8.self).baseAddress, UInt64(bytes.count)) }
        try check(status)
    }

    func process(_ pcm: [Float], language: String?) throws -> WhistleSegment {
        let status = pcm.withUnsafeBufferPointer { needle_stream_transcribe_process($0.baseAddress, Int32(pcm.count), language, nil, &out, Int32(out.count)) }
        return try decode(status)
    }

    func finish() throws -> WhistleSegment {
        try decode(needle_stream_transcribe_stop(&out, Int32(out.count)))
    }

    private func check(_ status: Int32) throws {
        guard status >= 0 else { throw WhistleError(code: status, reason: String(cString: needle_last_error())) }
    }

    private func decode(_ status: Int32) throws -> WhistleSegment {
        try check(status)
        return try JSONDecoder().decode(WhistleSegment.self, from: Data(out.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }))
    }
}
