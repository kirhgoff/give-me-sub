import Foundation
import Testing
@testable import GiveMeSub

struct ProblemReportTests {
    private let facts = ["GiveMeSub 0.1.1 (7)", "macOS 26.0"]
    private let lineLength = 40
    private let manyLines = 500

    @Test
    func `the issue link carries the title and diagnostics`() throws {
        let report = ProblemReport(facts: facts, logLines: ["first line", "second line"])

        let components = try #require(URLComponents(url: report.url, resolvingAgainstBaseURL: false))
        let body = try #require(components.queryItems?.first { $0.name == "body" }?.value)
        #expect(report.url.absoluteString.hasPrefix(ProblemReport.issuesURL.absoluteString))
        #expect(components.queryItems?.first { $0.name == "title" }?.value == ProblemReport.title)
        #expect(body.hasPrefix(ProblemReport.template))
        #expect(body.contains("- GiveMeSub 0.1.1 (7)\n- macOS 26.0"))
        #expect(body.contains("\(ProblemReport.logHeading)\n```\nfirst line\nsecond line\n```"))
    }

    @Test
    func `query characters survive the round trip`() throws {
        let report = ProblemReport(facts: ["Deutsch & more"], logLines: ["a+b=c? 100% \"quoted\" ünïcode"])

        let body = try #require(URLComponents(url: report.url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "body" }?.value)
        #expect(body.contains("- Deutsch & more"))
        #expect(body.contains("a+b=c? 100% \"quoted\" ünïcode"))
    }

    @Test
    func `a long log keeps the newest lines under the cap`() throws {
        let lines = (1...manyLines).map { "line \($0) " + String(repeating: "x", count: lineLength) }
        let report = ProblemReport(facts: facts, logLines: lines)

        let body = try #require(URLComponents(url: report.url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "body" }?.value)
        #expect(report.url.absoluteString.count <= ProblemReport.maxURLLength)
        #expect(body.contains("line \(manyLines) "))
        #expect(!body.contains("line 1 "))
    }
}
