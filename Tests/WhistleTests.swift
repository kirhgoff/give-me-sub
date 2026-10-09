import XCTest
import AVFoundation

final class WhistleTests: XCTestCase {
    func testStreamsSpokenSentence() throws {
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("givemesub-check.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--file-format=WAVE", "--data-format=LEF32@16000", "turn off the kitchen lights please"]
        try say.run(); say.waitUntilExit()

        let file = try AVAudioFile(forReading: wav)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        XCTAssertEqual(file.processingFormat.sampleRate, 16000)
        let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))

        let whistle = Whistle()
        try whistle.load(modelURL: Bundle(for: WhistleTests.self).url(forResource: "whistle", withExtension: "cact")!)
        var transcript = ""
        let done = expectation(description: "stream")
        for chunk in stride(from: 0, to: samples.count, by: 16000) {
            whistle.process(Array(samples[chunk..<min(chunk + 16000, samples.count)]), language: "en") { transcript += $0.text + " " }
        }
        whistle.stop { transcript += $0.text; done.fulfill() }
        wait(for: [done], timeout: 60)
        XCTAssertTrue(transcript.lowercased().contains("kitchen"), transcript)
    }
}
