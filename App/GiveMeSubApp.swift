import ServiceManagement
import SwiftUI

struct GiveMeSubApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private let languages: [(String, String?)] = [("Auto", nil), ("English", "en"), ("German", "de"), ("French", "fr"), ("Spanish", "es"), ("Italian", "it"), ("Dutch", "nl"), ("Polish", "pl")]

    var body: some Scene {
        @Bindable var captioner = delegate.captioner
        MenuBarExtra("GiveMeSub", systemImage: captioner.isRunning ? "captions.bubble.fill" : "captions.bubble") {
            Button(captioner.isRunning ? "Stop captions" : "Start captions") { captioner.toggle() }
            Picker("Language", selection: $captioner.language) {
                ForEach(languages, id: \.1) { Text($0.0).tag($0.1) }
            }
            Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: {
                try? $0 ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }))
            Text(captioner.lastText.isEmpty ? "—" : captioner.lastText).font(.caption).lineLimit(2)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
