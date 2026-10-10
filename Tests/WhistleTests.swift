import AVFoundation
import Testing
@testable import GiveMeSub

struct WhistleTests {
    private static let sampleRate = 16000.0
    private static let chunkSize = 16000

    @Test
    func `streams a spoken sentence`() async throws {
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("givemesub-check.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--file-format=WAVE", "--data-format=LEF32@16000", "turn off the kitchen lights please"]
        try say.run()
        say.waitUntilExit()

        let file = try AVAudioFile(forReading: wav)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        #expect(file.processingFormat.sampleRate == Self.sampleRate)
        let samples = Array(UnsafeBufferPointer(start: try #require(buffer.floatChannelData)[0], count: Int(buffer.frameLength)))

        let whistle = Whistle()
        try await whistle.load(modelURL: try #require(Bundle.main.url(forResource: "whistle", withExtension: "cact")))
        var transcript = ""
        for start in stride(from: 0, to: samples.count, by: Self.chunkSize) {
            let chunk = Array(samples[start..<min(start + Self.chunkSize, samples.count)])
            transcript += try await whistle.process(chunk, language: "en").text + " "
        }
        transcript += try await whistle.finish().text
        #expect(transcript.lowercased().contains("kitchen"), Comment(rawValue: transcript))
    }
}
