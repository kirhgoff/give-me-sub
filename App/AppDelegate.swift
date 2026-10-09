import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let captioner = Captioner()

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch url.host() {
            case "toggle": captioner.toggle()
            case "start": if !captioner.isRunning { captioner.start() }
            case "stop": if captioner.isRunning { captioner.stop() }
            default: NSLog("unknown link: %@", url.absoluteString)
            }
        }
    }
}
