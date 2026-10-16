import AppKit
import os

protocol RunningInstances {
    func otherInstance() -> URL?
    func forward(_ urls: [URL], to app: URL)
}

struct WorkspaceRunningInstances: RunningInstances {
    private nonisolated static let logger = Logger(subsystem: "com.kirhgoff.givemesub", category: "single-instance")

    func otherInstance() -> URL? {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return nil }
        let ownProcess = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0.processIdentifier != ownProcess }?
            .bundleURL
    }

    func forward(_ urls: [URL], to app: URL) {
        NSWorkspace.shared.open(
            urls,
            withApplicationAt: app,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: Self.makeCompletionHandler()
        )
    }

    private nonisolated static func makeCompletionHandler() -> @Sendable (NSRunningApplication?, (any Error)?) -> Void {
        { _, error in
            guard let error else { return }
            logger.error("forwarding links failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
