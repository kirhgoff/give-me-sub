import Foundation
import Testing
@testable import GiveMeSub

private final class FakePreferenceStore: PreferenceStore {
    private var values = [String: Any]()

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }
}

struct PreferencesTests {
    private let store = FakePreferenceStore()

    @Test
    func `language defaults to English`() {
        #expect(Preferences(store: store).language == .english)
    }

    @Test(arguments: [Language?.some(.german), nil])
    func `a chosen language is restored`(_ language: Language?) {
        Preferences(store: store).language = language

        #expect(Preferences(store: store).language == language)
    }

    @Test
    func `appearance changes are restored`() {
        let changed = CaptionAppearance(fontFamily: "Helvetica", fontSize: 40, isBold: false, textColor: .yellow, backgroundOpacity: 0.3)

        Preferences(store: store).appearance = changed

        #expect(Preferences(store: store).appearance == changed)
    }

    @Test
    func `an uninstalled font family falls back to the system font`() {
        Preferences(store: store).appearance.fontFamily = "No Such Font Family"

        #expect(Preferences(store: store).appearance.fontFamily == nil)
    }

    @Test
    func `unreadable appearance data falls back to the defaults`() {
        store.set(Data("x".utf8), forKey: Preferences.appearanceKey)

        #expect(Preferences(store: store).appearance == CaptionAppearance())
    }

    @Test
    func `caption mode defaults to rolling and is restored`() {
        #expect(Preferences(store: store).captionMode == .rolling)

        Preferences(store: store).captionMode = .subtitles

        #expect(Preferences(store: store).captionMode == .subtitles)
    }
}
