import XCTest
@testable import FanCore

final class AmbientCalibrationTests: XCTestCase {
    func testOffsetMatchesRoom() {
        XCTAssertEqual(AmbientCalibration.offset(room: 22, sensor: 29.64), -7.6, accuracy: 1e-9)
        XCTAssertEqual(AmbientCalibration.offset(room: 25.5, sensor: 24), 1.5, accuracy: 1e-9)
    }

    func testTinyGapIsPositiveZero() {
        let offset = AmbientCalibration.offset(room: 32, sensor: 32.04)
        XCTAssertEqual(offset, 0)
        XCTAssertFalse(offset.sign == .minus)
    }

    func testOffsetIsClamped() {
        XCTAssertEqual(AmbientCalibration.offset(room: 2, sensor: 30), -AmbientCalibration.maxOffset)
        XCTAssertEqual(AmbientCalibration.offset(room: 60, sensor: 30), AmbientCalibration.maxOffset)
    }

    func testApply() {
        XCTAssertEqual(AmbientCalibration.apply(-7.6, to: 29.6)!, 22, accuracy: 1e-9)
        XCTAssertNil(AmbientCalibration.apply(-7.6, to: nil))
        XCTAssertEqual(AmbientCalibration.apply(0, to: 30), 30)
    }
}
