import SwiftUI

@main struct GiveMeSubApp: App {
    @State private var captioner = Captioner()
    private let languages: [(String, String?)] = [("Auto", nil), ("English", "en"), ("German", "de"), ("French", "fr"), ("Spanish", "es"), ("Italian", "it"), ("Dutch", "nl"), ("Polish", "pl")]

    var body: some Scene {
        MenuBarExtra("GiveMeSub", systemImage: captioner.isRunning ? "captions.bubble.fill" : "captions.bubble") {
            Button(captioner.isRunning ? "Stop captions" : "Start captions") { captioner.toggle() }
            Picker("Language", selection: $captioner.language) {
                ForEach(languages, id: \.1) { Text($0.0).tag($0.1) }
            }
            Text(captioner.lastText.isEmpty ? "—" : captioner.lastText).font(.caption).lineLimit(2)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
