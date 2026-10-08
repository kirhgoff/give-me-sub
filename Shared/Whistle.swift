import Foundation
import CNeedle

struct WhistleSegment: Decodable {
    let text: String
    let pending: String
    let received: Double
}

final class Whistle {
    private let queue = DispatchQueue(label: "givemesub.whistle")
    private var out = [CChar](repeating: 0, count: 1 << 16)

    func load(modelURL: URL) throws {
        let bytes = try Data(contentsOf: modelURL)
        let rc = bytes.withUnsafeBytes { needle_load($0.bindMemory(to: UInt8.self).baseAddress, UInt64(bytes.count)) }
        if rc < 0 { throw NSError(domain: "Whistle", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: String(cString: needle_last_error())]) }
    }

    func process(_ pcm: [Float], language: String?, completion: @escaping (WhistleSegment) -> Void) {
        queue.async {
            let rc = pcm.withUnsafeBufferPointer { needle_stream_transcribe_process($0.baseAddress, Int32(pcm.count), language, nil, &self.out, Int32(self.out.count)) }
            if let segment = self.decode(rc) { completion(segment) }
        }
    }

    func stop(completion: @escaping (WhistleSegment) -> Void) {
        queue.async {
            let rc = needle_stream_transcribe_stop(&self.out, Int32(self.out.count))
            if let segment = self.decode(rc) { completion(segment) }
        }
    }

    private func decode(_ rc: Int32) -> WhistleSegment? {
        guard rc >= 0 else { NSLog("whistle: %@", String(cString: needle_last_error())); return nil }
        return try? JSONDecoder().decode(WhistleSegment.self, from: Data(String(cString: out).utf8))
    }
}
