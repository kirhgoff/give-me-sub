nonisolated struct CaptionAppearance: Codable, Equatable {
    static let fontSizes: ClosedRange<Double> = 16...64
    static let fontSizeStep = 2.0

    var fontFamily: String?
    var fontSize = 28.0
    var isBold = true
    var textColor = CaptionColor.white
    var backgroundOpacity = 0.7
}

nonisolated enum CaptionColor: String, Codable, CaseIterable, Identifiable {
    case white
    case yellow
    case cyan
    case green

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
