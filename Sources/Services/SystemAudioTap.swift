import AVFoundation
import CoreAudio

final class SystemAudioTap {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "givemesub.tap")
    private(set) var format: AVAudioFormat!

    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(description, &tapID))

        var asbd = AudioStreamBasicDescription()
        try read(tapID, kAudioTapPropertyFormat, &asbd)
        format = AVAudioFormat(streamDescription: &asbd)

        let outputUID = try defaultOutputUID()
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "GiveMeSub Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: description.uuid.uuidString]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID))

        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue, makeIOBlock(format: format, onBuffer: onBuffer)))
        try check(AudioDeviceStart(aggregateID, procID))
    }

    // A main-actor closure called on the tap queue traps at runtime, so the block is formed nonisolated.
    nonisolated private func makeIOBlock(format: AVAudioFormat, onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) -> AudioDeviceIOBlock {
        { _, input, _, _, _ in
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input) else { return }
            onBuffer(buffer)
        }
    }

    func stop() {
        if let procID { AudioDeviceStop(aggregateID, procID); AudioDeviceDestroyIOProcID(aggregateID, procID) }
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil; aggregateID = kAudioObjectUnknown; tapID = kAudioObjectUnknown
    }

    private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private func check(_ status: OSStatus) throws {
        if status != noErr { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    private func read<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: inout T) throws {
        var addr = address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        try check(AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value))
    }

    private func defaultOutputUID() throws -> String {
        var device = AudioDeviceID(kAudioObjectUnknown)
        try read(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultSystemOutputDevice, &device)
        var uid: Unmanaged<CFString>?
        try read(device, kAudioDevicePropertyDeviceUID, &uid)
        return uid!.takeRetainedValue() as String
    }
}
