import ServiceManagement
import SwiftUI
import os

@main struct GiveMeSubApp: App {
    private static let logger = Logger(subsystem: "com.kirill.givemesub", category: "launch-at-login")

    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var captioner: Captioner { delegate.captioner }

    var body: some Scene {
        MenuBarExtra("GiveMeSub", systemImage: statusIcon) {
            toggleButton
            languagePicker
            launchAtLoginToggle
            lastCaptionLabel
            Divider()
            quitButton
        }
    }

    private var statusIcon: String {
        captioner.isRunning ? "captions.bubble.fill" : "captions.bubble"
    }

    private var toggleButton: some View {
        Button(captioner.isRunning ? "Stop captions" : "Start captions") { captioner.toggle() }
    }

    private var languagePicker: some View {
        Picker("Language", selection: Bindable(captioner).language) {
            Text("Auto").tag(Language?.none)
            ForEach(Language.allCases) { language in
                Text(language.displayName).tag(Optional(language))
            }
        }
    }

    private var launchAtLoginToggle: some View {
        Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
    }

    private var lastCaptionLabel: some View {
        Text(captioner.lastText.isEmpty ? "—" : captioner.lastText).font(.caption).lineLimit(2)
    }

    private var quitButton: some View {
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.logger.error("launch at login \(enabled ? "register" : "unregister") failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
