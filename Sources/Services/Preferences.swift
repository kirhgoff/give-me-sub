import AppKit
import Observation
import os

@Observable
final class Preferences {
    static let languageKey = "language"
    static let appearanceKey = "captionAppearance"
    static let captionModeKey = "captionMode"
    static let autoLanguage = "auto"
    static let defaultLanguage = Language.english
    static let defaultCaptionMode = CaptionMode.rolling

    private static let logger = Logger(subsystem: "com.kirhgoff.givemesub", category: "preferences")

    var language: Language? {
        didSet { store.set(language?.rawValue ?? Self.autoLanguage, forKey: Self.languageKey) }
    }

    var appearance: CaptionAppearance {
        didSet { save(appearance) }
    }

    var captionMode: CaptionMode {
        didSet { store.set(captionMode.rawValue, forKey: Self.captionModeKey) }
    }

    private let store: any PreferenceStore

    init(store: any PreferenceStore = UserDefaults.standard) {
        self.store = store
        language = Self.loadLanguage(from: store)
        appearance = Self.loadAppearance(from: store)
        captionMode = store.string(forKey: Self.captionModeKey).flatMap(CaptionMode.init(rawValue:)) ?? Self.defaultCaptionMode
    }

    private static func loadLanguage(from store: any PreferenceStore) -> Language? {
        guard let stored = store.string(forKey: languageKey) else { return defaultLanguage }
        guard stored != autoLanguage else { return nil }
        return Language(rawValue: stored) ?? defaultLanguage
    }

    private static func loadAppearance(from store: any PreferenceStore) -> CaptionAppearance {
        guard let data = store.data(forKey: appearanceKey) else { return CaptionAppearance() }
        do {
            var appearance = try JSONDecoder().decode(CaptionAppearance.self, from: data)
            appearance.fontFamily = appearance.fontFamily.flatMap(installedFamily)
            return appearance
        } catch {
            logger.error("unreadable caption appearance: \(error, privacy: .public)")
            return CaptionAppearance()
        }
    }

    private static func installedFamily(_ family: String) -> String? {
        NSFontManager.shared.availableFontFamilies.contains(family) ? family : nil
    }

    private func save(_ appearance: CaptionAppearance) {
        do {
            store.set(try JSONEncoder().encode(appearance), forKey: Self.appearanceKey)
        } catch {
            Self.logger.error("caption appearance not saved: \(error, privacy: .public)")
        }
    }
}
