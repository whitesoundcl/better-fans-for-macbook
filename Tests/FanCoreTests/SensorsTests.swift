import XCTest
@testable import FanCore

final class SensorsTests: XCTestCase {
    func testAmbientPrefersTAOL() {
        XCTAssertEqual(SensorReader.ambientKey(from: ["Tp00", "TA0P", "TAOL", "TB0T"]), "TAOL")
    }

    func testAmbientFallsBackToFirstTAKey() {
        XCTAssertEqual(SensorReader.ambientKey(from: ["TA1P", "Tp00", "TA0P"]), "TA0P")
    }

    func testAmbientIgnoresLowercaseTaAndOthers() {
        XCTAssertNil(SensorReader.ambientKey(from: ["Ta0P", "Tp00", "TB0T"]))
    }

    func testAmbientGroupLabel() {
        XCTAssertEqual(AllSensorsReader.group(for: "TAOL"), "Ambiente")
        XCTAssertEqual(AllSensorsReader.group(for: "Ta0P"), "Otros · Ta*")
    }
}
