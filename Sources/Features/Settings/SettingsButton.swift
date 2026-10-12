import SwiftUI

struct SettingsButton: View {
    static let title = "Settings…"

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(Self.title) {
            NSApplication.shared.activate()
            openSettings()
        }
        .keyboardShortcut(",")
    }
}

#Preview {
    SettingsButton()
        .padding()
}
