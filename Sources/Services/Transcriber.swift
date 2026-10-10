nonisolated protocol Transcriber: Sendable {
    func prepare() async throws
    func process(_ chunk: [Float], language: Language?) async throws -> TranscriptSegment?
    func finish() async throws -> TranscriptSegment?
}
