import XCTest
@testable import FanCore

final class FanControllerTests: XCTestCase {
    let fans = [FanLimits(minRPM: 1500, maxRPM: 4300), FanLimits(minRPM: 1500, maxRPM: 4700)]

    func testCurveInterpolatesAndClamps() {
        let c = Curve(points: [.init(temp: 50, percent: 20), .init(temp: 70, percent: 60)])
        XCTAssertEqual(c.percent(at: 40), 20)
        XCTAssertEqual(c.percent(at: 60), 40, accuracy: 1e-9)
        XCTAssertEqual(c.percent(at: 99), 60)
    }

    func testPointsAreSortedAndPercentClamped() {
        let c = Curve(points: [.init(temp: 70, percent: 150), .init(temp: 50, percent: -5)])
        XCTAssertEqual(c.points.map(\.temp), [50, 70])
        XCTAssertEqual(c.points.map(\.percent), [0, 100])
    }

    func testAutoProfileReturnsAuto() {
        var ctl = FanController(profile: .apple)
        XCTAssertEqual(ctl.decide(temp: 70, fans: fans, dt: 1), .auto)
    }

    func testMissingSensorFallsBackToAuto() {
        var ctl = FanController(profile: .legsCool)
        XCTAssertEqual(ctl.decide(temp: nil, fans: fans, dt: 1), .auto)
    }

    func testFixedMaxMapsToEachFansMax() {
        var p = Profile.maximum
        p.rampUpRPMPerSec = 100_000
        var ctl = FanController(profile: p)
        XCTAssertEqual(ctl.decide(temp: 50, fans: fans, dt: 1), .rpm([4300, 4700]))
    }

    func testHardLimitIgnoresRampAndGoesToMax() {
        var ctl = FanController(profile: .quiet)
        _ = ctl.decide(temp: 40, fans: fans, dt: 1)
        XCTAssertEqual(ctl.decide(temp: 91, fans: fans, dt: 0.1), .rpm([4300, 4700]))
    }

    func testRampLimitsRiseAndFall() {
        var p = Profile.maximum
        p.rampUpRPMPerSec = 500
        var ctl = FanController(profile: Profile(name: "t", mode: .fixed(percent: 0), rampUpRPMPerSec: 500, rampDownRPMPerSec: 100))
        guard case .rpm(let start) = ctl.decide(temp: 50, fans: fans, dt: 1) else { return XCTFail() }
        XCTAssertEqual(start, [1500, 1500])
        ctl.profile.mode = .fixed(percent: 100)
        guard case .rpm(let up) = ctl.decide(temp: 50, fans: fans, dt: 1) else { return XCTFail() }
        XCTAssertEqual(up, [2000, 2000])
        ctl.profile.mode = .fixed(percent: 0)
        guard case .rpm(let down) = ctl.decide(temp: 50, fans: fans, dt: 1) else { return XCTFail() }
        XCTAssertEqual(down, [1900, 1900])
    }

    func testHysteresisHoldsSpeedOnSmallDrop() {
        var ctl = FanController(profile: Profile(name: "t",
            mode: .curve(Curve(points: [.init(temp: 40, percent: 0), .init(temp: 80, percent: 100)])),
            hysteresis: 3, rampUpRPMPerSec: 1e9, rampDownRPMPerSec: 1e9))
        guard case .rpm(let hot) = ctl.decide(temp: 70, fans: fans, dt: 1) else { return XCTFail() }
        guard case .rpm(let slight) = ctl.decide(temp: 68, fans: fans, dt: 1) else { return XCTFail() }
        XCTAssertEqual(hot, slight)
        guard case .rpm(let cooler) = ctl.decide(temp: 60, fans: fans, dt: 1) else { return XCTFail() }
        XCTAssertLessThan(cooler[0], hot[0])
    }

    func testProfileStoreRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("profiles-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProfileStore(url: url)
        var mine = Profile.legsCool
        mine.name = "Mi perfil"
        try store.save([mine])
        XCTAssertTrue(store.load().contains(mine))
        XCTAssertTrue(store.load().contains(.maximum))
    }
}
