import XCTest
@testable import FanCore

final class SMCDecodeTests: XCTestCase {
    func testFloatRoundTrip() {
        let bytes = SMCDecode.encodeFloat(2317.5)
        XCTAssertEqual(SMCDecode.number(type: "flt ", bytes: bytes), 2317.5)
    }

    func testSp78() {
        XCTAssertEqual(SMCDecode.number(type: "sp78", bytes: [0x2A, 0x80]), 42.5)
    }

    func testFpe2() {
        XCTAssertEqual(SMCDecode.number(type: "fpe2", bytes: [0x0B, 0xB8]), 750)
    }
}
