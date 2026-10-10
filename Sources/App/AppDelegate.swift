import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.kirill.givemesub", category: "links")

    let captioner: Captioner
    private let overlay: CaptionOverlay

    override init() {
        let captioner = Captioner()
        self.captioner = captioner
        overlay = CaptionOverlay(state: captioner.caption)
        super.init()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let command = url.host().flatMap(LinkCommand.init(rawValue:)) else {
                Self.logger.error("unknown link: \(url.absoluteString)")
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
