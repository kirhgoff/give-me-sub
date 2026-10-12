import AppIntents

struct ToggleCaptionsIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Captions"
    static let description = IntentDescription("Shows or hides live captions for the Mac's audio.")

    @Dependency private var captioner: Captioner

    @MainActor
    func perform() async throws -> some IntentResult {
        captioner.toggle()
        return .result()
    }
}

struct StartCaptionsIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Captions"
    static let description = IntentDescription("Starts live captions for the Mac's audio.")

    @Dependency private var captioner: Captioner

    @MainActor
    func perform() async throws -> some IntentResult {
        captioner.start()
        return .result()
    }
}

struct StopCaptionsIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Captions"
    static let description = IntentDescription("Stops live captions.")

    @Dependency private var captioner: Captioner

    @MainActor
    func perform() async throws -> some IntentResult {
        captioner.stop()
        return .result()
    }
}

nonisolated struct GiveMeSubShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ToggleCaptionsIntent(), phrases: ["Toggle captions in \(.applicationName)", "Toggle \(.applicationName)"], shortTitle: "Toggle Captions", systemImageName: "captions.bubble")
        AppShortcut(intent: StartCaptionsIntent(), phrases: ["Start captions in \(.applicationName)", "Start \(.applicationName)"], shortTitle: "Start Captions", systemImageName: "captions.bubble.fill")
        AppShortcut(intent: StopCaptionsIntent(), phrases: ["Stop captions in \(.applicationName)", "Stop \(.applicationName)"], shortTitle: "Stop Captions", systemImageName: "captions.bubble")
    }
}
