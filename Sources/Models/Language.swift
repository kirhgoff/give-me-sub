nonisolated enum Language: String, CaseIterable, Identifiable {
    case english = "en"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case dutch = "nl"
    case polish = "pl"

    var id: String { rawValue }
    var displayName: String { "\(self)".capitalized }
}
