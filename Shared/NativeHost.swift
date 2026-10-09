import Foundation

enum NativeHost {
    static let caption = Notification.Name("com.kirill.givemesub.caption")
    static let extensionID = "givemesub@kirill"
    static let manifestURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/Mozilla/NativeMessagingHosts/givemesub.json")

    static func installManifest() {
        let manifest: [String: Any] = [
            "name": "givemesub",
            "description": "GiveMeSub live captions",
            "path": Bundle.main.executablePath!,
            "type": "stdio",
            "allowed_extensions": [extensionID],
        ]
        try? FileManager.default.createDirectory(at: manifestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted).write(to: manifestURL)
    }

    static func frame(_ payload: [String: Any]) -> Data {
        let json = try! JSONSerialization.data(withJSONObject: payload)
        var length = UInt32(json.count)
        return Data(bytes: &length, count: 4) + json
    }

    // ponytail: host mode is detected by Firefox appending the extension id as the last argv; split into its own target if that stops holding
    static func serve() -> Never {
        let observer = DistributedNotificationCenter.default().addObserver(forName: caption, object: nil, queue: nil) {
            FileHandle.standardOutput.write(frame($0.userInfo as? [String: Any] ?? [:]))
        }
        DispatchQueue.global().async { while readLine() != nil {}; exit(0) }
        withExtendedLifetime(observer) { RunLoop.main.run() }
        exit(0)
    }
}
