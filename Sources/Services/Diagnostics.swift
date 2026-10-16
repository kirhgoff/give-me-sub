import Foundation
import OSLog
import os

nonisolated struct Diagnostics {
    static let subsystem = "com.kirhgoff.givemesub"
    static let versionKey = "CFBundleShortVersionString"
    static let buildKey = "CFBundleVersion"
    static let modelKey = "hw.model"
    static let machineKey = "hw.machine"
    static let unknown = "?"
    private static let logger = Logger(subsystem: subsystem, category: "diagnostics")

    var facts: [String] {
        let info = Bundle.main.infoDictionary ?? [:]
        return [
            "GiveMeSub \(info[Self.versionKey] ?? Self.unknown) (\(info[Self.buildKey] ?? Self.unknown))",
            "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "\(Self.sysctl(Self.modelKey)) \(Self.sysctl(Self.machineKey))",
        ]
    }

    @concurrent func recentLogLines(limit: Int) async -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let newestFirst = try store.getEntries(with: [.reverse], at: nil, matching: NSPredicate(format: "subsystem == %@", Self.subsystem))
            return newestFirst
                .compactMap { $0 as? OSLogEntryLog }
                .prefix(limit)
                .reversed()
                .map { "\($0.date.formatted(.iso8601)) [\($0.category)] \($0.composedMessage)" }
        } catch {
            Self.logger.error("log read failed: \(error, privacy: .public)")
            return []
        }
    }

    private static func sysctl(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return unknown }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return unknown }
        return String(cString: buffer)
    }
}
