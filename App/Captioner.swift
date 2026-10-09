import AVFoundation
import SafariServices
import Observation

@Observable final class Captioner {
    var isRunning = false
    var language: String? = nil
    var lastText = ""
    @ObservationIgnored private let whistle = Whistle()
    @ObservationIgnored private let overlay = CaptionOverlay()
    @ObservationIgnored private let tap = SystemAudioTap()
    @ObservationIgnored private var converter: AVAudioConverter?
    @ObservationIgnored private var pending = [Float]()
    @ObservationIgnored private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    @ObservationIgnored private var loaded = false

    func toggle() { isRunning ? stop() : start() }

    private func start() {
        do {
            if !loaded { try whistle.load(modelURL: Bundle.main.url(forResource: "whistle", withExtension: "cact")!); loaded = true }
            try tap.start { [weak self] buffer in self?.ingest(buffer) }
            converter = AVAudioConverter(from: tap.format, to: target)
            isRunning = true
        } catch { NSLog("start failed: %@", "\(error)") }
    }

    private func stop() {
        tap.stop()
        whistle.stop { [weak self] in self?.publish($0) }
        pending.removeAll()
        isRunning = false
    }

    private func ingest(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * 16000 / buffer.format.sampleRate) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var consumed = false
        converter.convert(to: out, error: nil) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        pending.append(contentsOf: UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength)))
        while pending.count >= 16000 {
            let chunk = Array(pending.prefix(16000))
            pending.removeFirst(16000)
            whistle.process(chunk, language: language) { [weak self] in self?.publish($0) }
        }
    }

    private func publish(_ segment: WhistleSegment) {
        guard !segment.text.isEmpty || !segment.pending.isEmpty else { return }
        DispatchQueue.main.async {
            self.lastText = segment.text
            self.overlay.show(text: segment.text, pending: segment.pending)
        }
        let payload: [String: Any] = ["text": segment.text, "pending": segment.pending, "received": segment.received]
        DistributedNotificationCenter.default().postNotificationName(NativeHost.caption, object: nil, userInfo: payload, deliverImmediately: true)
        SFSafariApplication.dispatchMessage(withName: "caption", toExtensionWithIdentifier: "com.kirill.givemesub.Extension", userInfo: payload) { error in
            if let error { NSLog("dispatch failed: %@", "\(error)") }
        }
    }
}
