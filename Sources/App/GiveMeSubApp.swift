import ServiceManagement
import SwiftUI

@main struct GiveMeSubApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some Scene {
        @Bindable var captioner = delegate.captioner
        MenuBarExtra("GiveMeSub", systemImage: captioner.isRunning ? "captions.bubble.fill" : "captions.bubble") {
            Button(captioner.isRunning ? "Stop captions" : "Start captions") { captioner.toggle() }
            Picker("Language", selection: $captioner.language) {
                Text("Auto").tag(Language?.none)
                ForEach(Language.allCases) { Text($0.displayName).tag(Optional($0)) }
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
