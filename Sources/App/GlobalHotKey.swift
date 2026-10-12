import Carbon.HIToolbox
import os

final class GlobalHotKey {
    static let toggleKeyCode = UInt32(kVK_ANSI_C)
    static let toggleModifiers = UInt32(controlKey | optionKey | cmdKey)
    static let toggleDisplay = "⌃⌥⌘C"
    private static let signature: OSType = 0x474D_5342
    private static let identifier: UInt32 = 1
    private static let logger = Logger(subsystem: "com.kirhgoff.givemesub", category: "hotkey")

    let presses: AsyncStream<Void>
    private let sink: Sink
    private let keyCode: UInt32
    private let modifiers: UInt32
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init(keyCode: UInt32 = GlobalHotKey.toggleKeyCode, modifiers: UInt32 = GlobalHotKey.toggleModifiers) {
        let (presses, continuation) = AsyncStream.makeStream(of: Void.self)
        self.presses = presses
        sink = Sink(continuation: continuation)
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), Self.makeHandler(), 1, &eventType, Unmanaged.passUnretained(sink).toOpaque(), &handler)
        guard installStatus == noErr else {
            Self.logger.error("hotkey handler install failed: \(installStatus)")
            return
        }
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.identifier)
        let registerStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKey)
        guard registerStatus == noErr else {
            Self.logger.error("hotkey \(Self.toggleDisplay, privacy: .public) unavailable: \(registerStatus)")
            return
        }
    }

    // A main-actor closure called from the C event handler traps at runtime, so it is formed nonisolated.
    nonisolated private static func makeHandler() -> EventHandlerUPP {
        { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            Unmanaged<Sink>.fromOpaque(userData).takeUnretainedValue().continuation.yield()
            return noErr
        }
    }

    nonisolated private final class Sink: Sendable {
        let continuation: AsyncStream<Void>.Continuation

        init(continuation: AsyncStream<Void>.Continuation) {
            self.continuation = continuation
        }
    }
}
