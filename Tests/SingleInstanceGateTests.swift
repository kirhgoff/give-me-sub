import Foundation
import Testing
@testable import GiveMeSub

private final class FakeRunningInstances: RunningInstances {
    let other: URL?
    private(set) var forwards: [(urls: [URL], app: URL)] = []

    init(other: URL?) {
        self.other = other
    }

    func otherInstance() -> URL? {
        other
    }

    func forward(_ urls: [URL], to app: URL) {
        forwards.append((urls, app))
    }
}

struct SingleInstanceGateTests {
    private let links = [URL(string: "givemesub://start")!]
    private let runningCopy = URL(filePath: "/Applications/GiveMeSub.app")

    @Test
    func `the only copy keeps running and forwards nothing`() {
        let instances = FakeRunningInstances(other: nil)
        let gate = SingleInstanceGate(instances: instances)

        #expect(gate.launch())
        #expect(!gate.forward(links))
        #expect(instances.forwards.isEmpty)
    }

    @Test
    func `a second copy quits and forwards links to the running one`() throws {
        let instances = FakeRunningInstances(other: runningCopy)
        let gate = SingleInstanceGate(instances: instances)

        #expect(!gate.launch())
        #expect(gate.forward(links))

        let forward = try #require(instances.forwards.first)
        #expect(instances.forwards.count == 1)
        #expect(forward.urls == links)
        #expect(forward.app == runningCopy)
    }
}
