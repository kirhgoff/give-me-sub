nonisolated enum CaptionMode: String, CaseIterable, Identifiable {
    case rolling
    case subtitles

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
