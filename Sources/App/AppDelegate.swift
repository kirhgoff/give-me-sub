import AppIntents
import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.kirhgoff.givemesub", category: "links")

    let captioner: Captioner
    let preferences: Preferences
    private let overlay: CaptionOverlay
    private let hotKey = GlobalHotKey()
    private var hotKeyTask: Task<Void, Never>?
    private let singleInstance: SingleInstanceGate
    private var keepsRunning = true

    override convenience init() {
        self.init(singleInstance: SingleInstanceGate())
    }

    init(singleInstance: SingleInstanceGate) {
        self.singleInstance = singleInstance
        let preferences = Preferences()
        let captioner = Captioner(preferences: preferences)
        self.preferences = preferences
        self.captioner = captioner
        AppDependencyManager.shared.add(dependency: captioner)
        overlay = CaptionOverlay(state: captioner.caption, preferences: preferences)
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        keepsRunning = singleInstance.launch()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard keepsRunning else {
            NSApplication.shared.terminate(nil)
            return
        }
        hotKey.register()
        let presses = hotKey.presses
        hotKeyTask = Task { [weak self] in
            for await _ in presses {
                guard let self else { return }
                captioner.toggle()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !singleInstance.forward(urls) else { return }
        for url in urls {
            guard let command = url.host().flatMap(LinkCommand.init(rawValue:)) else {
                Self.logger.error("unknown link: \(url.absoluteString, privacy: .public)")
                continue
            }
            run(command)
        }
    }

    private func run(_ command: LinkCommand) {
        switch command {
        case .toggle: captioner.toggle()
        case .start: captioner.start()
        case .stop: captioner.stop()
        }
    }
}
