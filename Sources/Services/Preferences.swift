import Foundation
import Observation
import os

@Observable
final class Preferences {
    static let languageKey = "language"
    static let appearanceKey = "captionAppearance"
    static let autoLanguage = "auto"
    static let defaultLanguage = Language.english

    private static let logger = Logger(subsystem: "com.kirhgoff.givemesub", category: "preferences")

    var language: Language? {
        didSet { store.set(language?.rawValue ?? Self.autoLanguage, forKey: Self.languageKey) }
    }

    var appearance: CaptionAppearance {
        didSet { save(appearance) }
    }

    private let store: any PreferenceStore

    init(store: any PreferenceStore = UserDefaults.standard) {
        self.store = store
        language = Self.loadLanguage(from: store)
        appearance = Self.loadAppearance(from: store)
    }

    private static func loadLanguage(from store: any PreferenceStore) -> Language? {
        guard let stored = store.string(forKey: languageKey) else { return defaultLanguage }
        guard stored != autoLanguage else { return nil }
        return Language(rawValue: stored) ?? defaultLanguage
    }

    private static func loadAppearance(from store: any PreferenceStore) -> CaptionAppearance {
        guard let data = store.data(forKey: appearanceKey) else { return CaptionAppearance() }
        do {
            return try JSONDecoder().decode(CaptionAppearance.self, from: data)
        } catch {
            logger.error("unreadable caption appearance: \(error)")
            return CaptionAppearance()
        }
    }

    private func save(_ appearance: CaptionAppearance) {
        do {
            store.set(try JSONEncoder().encode(appearance), forKey: Self.appearanceKey)
        } catch {
            Self.logger.error("caption appearance not saved: \(error)")
        }
    }
}
