nonisolated struct SampleChunker {
    private var carry = [Float]()

    mutating func append(_ samples: [Float]) -> [[Float]] {
        carry.append(contentsOf: samples)
        var chunks = [[Float]]()
        while carry.count >= SpeechFormat.samplesPerChunk {
            chunks.append(Array(carry.prefix(SpeechFormat.samplesPerChunk)))
            carry.removeFirst(SpeechFormat.samplesPerChunk)
        }
        return chunks
    }
}
