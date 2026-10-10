import AVFoundation
import Testing
@testable import GiveMeSub

struct WhistleTests {
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
        #expect(file.processingFormat.sampleRate == SpeechFormat.sampleRate)
        let samples = Array(UnsafeBufferPointer(start: try #require(buffer.floatChannelData)[0], count: Int(buffer.frameLength)))

        let whistle: any Transcriber = Whistle()
        try await whistle.prepare()
        var transcript = ""
        for start in stride(from: 0, to: samples.count, by: SpeechFormat.samplesPerChunk) {
            let chunk = Array(samples[start..<min(start + SpeechFormat.samplesPerChunk, samples.count)])
            transcript += try await whistle.process(chunk, language: .english)?.text ?? ""
            transcript += " "
        }
        transcript += try await whistle.finish()?.text ?? ""
        #expect(transcript.lowercased().contains("kitchen"), Comment(rawValue: transcript))
    }
}
