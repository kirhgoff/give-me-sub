import AppKit
import ServiceManagement
import SwiftUI
import os

struct SettingsView: View {
    static let width: CGFloat = 420
    static let launchAtLoginTitle = "Launch at login"
    static let systemFont = "System"
    static let modeTitle = "Mode"
    static let fontTitle = "Font"
    static let fontSizeTitle = "Size"
    static let boldTitle = "Bold"
    static let textColorTitle = "Text colour"
    static let backgroundTitle = "Background opacity"
    static let generalSection = "General"
    static let appearanceSection = "Captions"
    static let opacityRange = 0.0...1.0

    private static let fontFamilies = NSFontManager.shared.availableFontFamilies
    private static let logger = Logger(subsystem: "com.kirhgoff.givemesub", category: "launch-at-login")

    @Bindable var preferences: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            generalSection
            appearanceSection
        }
        .formStyle(.grouped)
        .frame(width: Self.width)
    }

    private var generalSection: some View {
        Section(Self.generalSection) {
            launchAtLoginToggle
            LanguagePicker(selection: $preferences.language)
        }
    }

    private var appearanceSection: some View {
        Section(Self.appearanceSection) {
            modePicker
            fontPicker
            fontSizeSlider
            boldToggle
            textColorPicker
            backgroundSlider
        }
    }

    private var launchAtLoginToggle: some View {
        Toggle(Self.launchAtLoginTitle, isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
    }

    private var modePicker: some View {
        Picker(Self.modeTitle, selection: $preferences.captionMode) {
            ForEach(CaptionMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
    }

    private var fontPicker: some View {
        Picker(Self.fontTitle, selection: $preferences.appearance.fontFamily) {
            Text(Self.systemFont).tag(String?.none)
            ForEach(Self.fontFamilies, id: \.self) { family in
                Text(family).tag(Optional(family))
            }
        }
    }

    private var fontSizeSlider: some View {
        LabeledContent(Self.fontSizeTitle) {
            HStack {
                Slider(value: $preferences.appearance.fontSize, in: CaptionAppearance.fontSizes, step: CaptionAppearance.fontSizeStep)
                Text("\(Int(preferences.appearance.fontSize))")
            }
        }
    }

    private var boldToggle: some View {
        Toggle(Self.boldTitle, isOn: $preferences.appearance.isBold)
    }

    private var textColorPicker: some View {
        Picker(Self.textColorTitle, selection: $preferences.appearance.textColor) {
            ForEach(CaptionColor.allCases) { color in
                Text(color.displayName).tag(color)
            }
        }
    }

    private var backgroundSlider: some View {
        LabeledContent(Self.backgroundTitle) {
            Slider(value: $preferences.appearance.backgroundOpacity, in: Self.opacityRange)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.logger.error("launch at login \(enabled ? "register" : "unregister", privacy: .public) failed: \(error, privacy: .public)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

#Preview {
    SettingsView(preferences: Preferences())
}
