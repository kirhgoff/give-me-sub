import Foundation

nonisolated struct ProblemReport {
    static let issuesURL = URL(string: "https://github.com/kirhgoff/give-me-sub/issues/new")!
    static let title = "Problem report"
    static let maxURLLength = 8000
    static let maxLogLines = 100
    static let template = """
        ## What happened

        ## What was playing

        ## Steps to reproduce

        ## Diagnostics
        """
    static let logHeading = "## Recent log"
    private static let queryAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))

    var facts: [String]
    var logLines: [String]

    var url: URL {
        var lines = logLines
        var url = Self.url(facts: facts, logLines: lines)
        while url.absoluteString.count > Self.maxURLLength, !lines.isEmpty {
            lines.removeFirst()
            url = Self.url(facts: facts, logLines: lines)
        }
        return url
    }

    static func body(facts: [String], logLines: [String]) -> String {
        let diagnostics = facts.map { "- \($0)" }.joined(separator: "\n")
        let log = logLines.joined(separator: "\n")
        return "\(template)\n\(diagnostics)\n\n\(logHeading)\n```\n\(log)\n```\n"
    }

    private static func url(facts: [String], logLines: [String]) -> URL {
        URL(string: "\(issuesURL.absoluteString)?title=\(encode(title))&body=\(encode(body(facts: facts, logLines: logLines)))")!
    }

    private static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? ""
    }
}
