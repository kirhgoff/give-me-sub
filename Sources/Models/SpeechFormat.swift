import Foundation

nonisolated enum SpeechFormat {
    static let sampleRate = 16_000.0
    static let chunkDuration: TimeInterval = 1
    static let samplesPerChunk = Int(sampleRate * chunkDuration)
}
