import AVFoundation
import CoreAudio

nonisolated enum AudioTapError: Error {
    case unsupportedFormat
}

final class SystemAudioTap: AudioSource {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var continuation: AsyncStream<[Float]>.Continuation?
    private let queue = DispatchQueue(label: "givemesub.tap")

    func start() throws -> AsyncStream<[Float]> {
        stop()
        let (stream, continuation) = AsyncStream.makeStream(of: [Float].self)
        self.continuation = continuation
        do {
            try open(yielding: continuation)
        } catch {
            stop()
            throw error
        }
        return stream
    }

    func stop() {
        if let procID { AudioDeviceStop(aggregateID, procID); AudioDeviceDestroyIOProcID(aggregateID, procID) }
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil; aggregateID = kAudioObjectUnknown; tapID = kAudioObjectUnknown
        continuation?.finish()
        continuation = nil
    }

    private func open(yielding continuation: AsyncStream<[Float]>.Continuation) throws {
        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(description, &tapID))

        var asbd = AudioStreamBasicDescription()
        try read(tapID, kAudioTapPropertyFormat, &asbd)
        guard let format = AVAudioFormat(streamDescription: &asbd), let resampler = Resampler(from: format) else { throw AudioTapError.unsupportedFormat }

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

        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue, makeIOBlock(format: format, resampler: resampler, continuation: continuation)))
        try check(AudioDeviceStart(aggregateID, procID))
    }

    // A main-actor closure called on the tap queue traps at runtime, so the block is formed nonisolated.
    nonisolated private func makeIOBlock(format: AVAudioFormat, resampler: Resampler, continuation: AsyncStream<[Float]>.Continuation) -> AudioDeviceIOBlock {
        { _, input, _, _, _ in
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input) else { return }
            let samples = resampler.convert(buffer)
            guard !samples.isEmpty else { return }
            continuation.yield(samples)
        }
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
        try withUnsafeMutablePointer(to: &value) { try check(AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)) }
    }

    private func defaultOutputUID() throws -> String {
        var device = AudioDeviceID(kAudioObjectUnknown)
        try read(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultSystemOutputDevice, &device)
        var uid: Unmanaged<CFString>?
        try read(device, kAudioDevicePropertyDeviceUID, &uid)
        return uid!.takeRetainedValue() as String
    }
}
