import Observation

@Observable
final class CaptionState {
    static let maxWords = 18

    private(set) var committed = ""
    private(set) var pending = ""
    private(set) var isVisible = false

    private let timing: CaptionTiming
    @ObservationIgnored private var hideTask: Task<Void, Error>?

    init(timing: CaptionTiming = CaptionTiming()) {
        self.timing = timing
    }

    func show(_ segment: TranscriptSegment) {
        if !segment.text.isEmpty {
            committed = (committed + " " + segment.text).split(separator: " ").suffix(Self.maxWords).joined(separator: " ")
        }
        pending = segment.pending
        reveal(for: timing.hideDelay)
    }

    func flash(_ text: String) {
        committed = text
        pending = ""
        reveal(for: timing.flashDuration)
    }

    private func reveal(for duration: Duration) {
        isVisible = true
        hideTask?.cancel()
        hideTask = Task { [weak self] in
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
