import Observation

@Observable
final class CaptionState {
    static let maxWords = 18

    private(set) var committed = ""
    private(set) var pending = ""
    private(set) var isVisible = false

    private let timing: CaptionTiming
    @ObservationIgnored private var presentationTask: Task<Void, Error>?

    @ObservationIgnored private var timeline: SubtitleTimeline

    init(timing: CaptionTiming = CaptionTiming()) {
        self.timing = timing
        timeline = SubtitleTimeline(timing: timing)
    }

    func show(_ segment: TranscriptSegment) {
        timeline = SubtitleTimeline(timing: timing)
        if !segment.text.isEmpty {
            committed = (committed + " " + segment.text).split(separator: " ").suffix(Self.maxWords).joined(separator: " ")
        }
        pending = segment.pending
        reveal(for: timing.hideDelay)
    }

    func flash(_ text: String) {
        present(text, for: timing.flashDuration)
    }

    func warn(_ text: String) {
        present(text, for: timing.warningDuration)
    }

    func showSubtitle(_ text: String) {
        guard !text.allSatisfy(\.isWhitespace) else { return }
        timeline.append(text, at: .now)
        presentSubtitles()
    }

    private func presentSubtitles() {
        let now = ContinuousClock.now
        let cue = timeline.advance(to: now)
        committed = cue ?? ""
        pending = ""
        isVisible = cue != nil
        presentationTask?.cancel()
        guard let next = timeline.nextChange(after: now) else { return }
        presentationTask = Task { [weak self] in
            try await Task.sleep(until: next, clock: .continuous)
            self?.presentSubtitles()
        }
    }

    private func present(_ text: String, for duration: Duration) {
        timeline = SubtitleTimeline(timing: timing)
        committed = text
        pending = ""
        reveal(for: duration)
    }

    private func reveal(for duration: Duration) {
        isVisible = true
        presentationTask?.cancel()
        presentationTask = Task { [weak self] in
            try await Task.sleep(for: duration)
            self?.hide()
        }
    }

    private func hide() {
        isVisible = false
        committed = ""
        pending = ""
    }
}
