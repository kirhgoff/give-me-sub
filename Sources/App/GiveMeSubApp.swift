import SwiftUI

@main struct GiveMeSubApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    private var captioner: Captioner { delegate.captioner }

    var body: some Scene {
        MenuBarExtra("GiveMeSub", image: statusIcon) {
            toggleButton
            LanguagePicker(selection: Bindable(delegate.preferences).language)
            SettingsButton()
            Divider()
            quitButton
        }
        Settings {
            SettingsView(preferences: delegate.preferences)
        }
    }

    private var statusIcon: String {
        captioner.isRunning ? "MenuBarIcon" : "MenuBarIconOff"
    }

    private var toggleButton: some View {
        Button(captioner.isRunning ? "Stop captions" : "Start captions") { captioner.toggle() }
    }

    private var quitButton: some View {
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}
