import Foundation

final class SingleInstanceGate {
    private let instances: any RunningInstances
    private var runningCopy: URL?

    init(instances: any RunningInstances = WorkspaceRunningInstances()) {
        self.instances = instances
    }

    func launch() -> Bool {
        runningCopy = instances.otherInstance()
        return runningCopy == nil
    }

    func forward(_ urls: [URL]) -> Bool {
        guard let runningCopy else { return false }
        instances.forward(urls, to: runningCopy)
        return true
    }
}
