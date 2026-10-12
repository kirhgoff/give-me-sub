import Testing
@testable import GiveMeSub

nonisolated struct ReadingCase: Sendable {
    let wordCount: Int
    let held: Duration
}

struct SubtitleTimelineTests {
    private let start = ContinuousClock.now

    @Test(arguments: [".", "?", "!"])
    func `a sentence ending releases a cue`(_ ending: String) {
        var timeline = SubtitleTimeline()

        timeline.append("Read me the weather\(ending)", at: start)

        #expect(timeline.advance(to: start) == "Read me the weather\(ending)")
    }

    @Test
    func `words without a sentence ending wait`() {
        var timeline = SubtitleTimeline()

        timeline.append("Turn off the kitchen lights please, and then", at: start)

        #expect(timeline.advance(to: start) == nil)
    }

    @Test
    func `a cue is released at the word cap`() throws {
        var timeline = SubtitleTimeline()

        timeline.append("Turn off the kitchen lights please, and then", at: start)
        timeline.append("read me the", at: start)
        timeline.append("weather forecast for tomorrow morning.", at: start)

        #expect(timeline.advance(to: start) == "Turn off the kitchen lights please, and then read me the weather")
        let second = try #require(timeline.nextChange(after: start))
        #expect(timeline.advance(to: second) == "forecast for tomorrow morning.")
    }

    @Test(arguments: [
        ReadingCase(wordCount: 1, held: .milliseconds(1500)),
        ReadingCase(wordCount: 4, held: .milliseconds(1500)),
        ReadingCase(wordCount: 8, held: .milliseconds(2400)),
        ReadingCase(wordCount: 12, held: .milliseconds(3500)),
    ])
    func `a cue is held for its reading time`(_ reading: ReadingCase) {
        var timeline = SubtitleTimeline()
        let words = Array(repeating: "word", count: reading.wordCount - 1) + ["end."]

        timeline.append(words.joined(separator: " "), at: start)

        #expect(timeline.advance(to: start + reading.held - .milliseconds(1)) != nil)
        #expect(timeline.advance(to: start + reading.held) == nil)
        #expect(timeline.nextChange(after: start + reading.held) == nil)
    }

    @Test
    func `cues that arrive faster than they are read wait their turn`() {
        var timeline = SubtitleTimeline()

        timeline.append("One two three.", at: start)
        timeline.append("Four five six.", at: start)

        #expect(timeline.advance(to: start) == "One two three.")
        #expect(timeline.advance(to: start + .milliseconds(1500)) == "Four five six.")
        #expect(timeline.advance(to: start + .seconds(3)) == nil)
    }

    @Test
    func `a pause releases the unfinished cue`() {
        var timeline = SubtitleTimeline()

        timeline.append("and then", at: start)

        #expect(timeline.advance(to: start + .milliseconds(1999)) == nil)
        #expect(timeline.nextChange(after: start) == start + .seconds(2))
        #expect(timeline.advance(to: start + .seconds(2)) == "and then")
    }

    @Test
    func `passes without new words keep the pause running`() {
        var timeline = SubtitleTimeline()

        timeline.append("and then", at: start)
        timeline.append("", at: start + .seconds(1))
        timeline.append(" ", at: start + .seconds(2))

        #expect(timeline.advance(to: start + .seconds(2)) == "and then")
    }

    @Test
    func `a backlog of short cues never runs further behind than the maximum delay`() {
        var timeline = SubtitleTimeline()

        for second in 0..<60 {
            timeline.append("Line\(second).", at: start + .seconds(second))
        }

        #expect(timeline.advance(to: start + .seconds(59)) == "Line55.")
    }

    @Test
    func `nothing changes again at the instant a cue ends`() {
        var timeline = SubtitleTimeline()

        timeline.append("One two three.", at: start)

        #expect(timeline.nextChange(after: start + .milliseconds(1500)) == nil)
    }

    @Test
    func `blank text adds nothing`() {
        var timeline = SubtitleTimeline()

        timeline.append("  ", at: start)

        #expect(timeline.advance(to: start) == nil)
        #expect(timeline.nextChange(after: start) == nil)
    }
}
