import SwiftUI

struct ReportProblemButton: View {
    static let title = "Report a Problem…"

    let isRunning: Bool
    let preferences: Preferences
    var diagnostics = Diagnostics()

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(Self.title) {
            Task { await report() }
        }
    }

    private var settingsFact: String {
        "Language: \(preferences.language?.rawValue ?? Preferences.autoLanguage), mode: \(preferences.captionMode.rawValue), captions running: \(isRunning)"
    }

    private func report() async {
        let report = ProblemReport(
            facts: diagnostics.facts + [settingsFact],
            logLines: await diagnostics.recentLogLines(limit: ProblemReport.maxLogLines)
        )
        openURL(report.url)
    }
}

#Preview {
    ReportProblemButton(isRunning: false, preferences: Preferences())
        .padding()
}
