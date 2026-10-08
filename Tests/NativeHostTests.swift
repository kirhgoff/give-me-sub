import XCTest

final class NativeHostTests: XCTestCase {
    func testFramesLengthPrefixedJSON() throws {
        let framed = NativeHost.frame(["text": "hi"])
        XCTAssertEqual(framed.prefix(4), Data([13, 0, 0, 0]))
        XCTAssertEqual(try JSONSerialization.jsonObject(with: framed.dropFirst(4)) as? [String: String], ["text": "hi"])
    }
}
