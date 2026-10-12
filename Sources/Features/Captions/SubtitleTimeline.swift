nonisolated struct SubtitleTimeline {
    typealias Instant = ContinuousClock.Instant

    static let maxWords = 12
    static let sentenceEndings: Set<Character> = [".", "?", "!"]

    private let timing: CaptionTiming
    private var words = [String]()
    private var lastWordAt: Instant?
    private var cues = [Cue]()

    init(timing: CaptionTiming = CaptionTiming()) {
        self.timing = timing
    }

    mutating func append(_ text: String, at now: Instant) {
        for word in text.split(whereSeparator: \.isWhitespace) {
            words.append(String(word))
            if words.count == Self.maxWords || word.last.map(Self.sentenceEndings.contains) == true {
                release(at: now)
            }
        }
        lastWordAt = words.isEmpty ? nil : now
    }

    mutating func advance(to now: Instant) -> String? {
        if let lastWordAt, now >= lastWordAt + timing.cueIdleRelease {
            release(at: now)
        }
        cues.removeAll { $0.end <= now }
        return cues.first { $0.start <= now }?.text
    }

    func nextChange(after now: Instant) -> Instant? {
        var changes = cues.flatMap { [$0.start, $0.end] }
        if let lastWordAt {
            changes.append(lastWordAt + timing.cueIdleRelease)
        }
        return changes.filter { $0 > now }.min()
    }

    private mutating func release(at now: Instant) {
        guard !words.isEmpty else { return }
        let start = max(now, cues.last?.end ?? now)
        cues.append(Cue(text: words.joined(separator: " "), start: start, end: start + readingTime(wordCount: words.count)))
        words.removeAll()
        lastWordAt = nil
    }

    private func readingTime(wordCount: Int) -> Duration {
        min(max(timing.cueTimePerWord * wordCount, timing.cueMinimum), timing.cueMaximum)
    }

    nonisolated private struct Cue {
        let text: String
        let start: Instant
        let end: Instant
    }
}
