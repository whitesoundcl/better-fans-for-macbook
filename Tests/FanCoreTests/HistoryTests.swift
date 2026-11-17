import XCTest
@testable import FanCore

final class HistoryTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func sample(_ s: TimeInterval, cpu: Double?, gpu: Double? = nil, rpm: [Double] = []) -> HistorySample {
        HistorySample(time: t0.addingTimeInterval(s), cpu: cpu, gpu: gpu, rpm: rpm)
    }

    func testAppendDropsOldAndOutOfOrder() {
        var h = TemperatureHistory(window: 10)
        for s in 0...20 { h.append(sample(Double(s), cpu: Double(s))) }
        h.append(sample(5, cpu: 99))                       // older than last: ignored
        XCTAssertEqual(h.samples.first?.cpu, 10)           // 20 - 10 s window
        XCTAssertEqual(h.samples.last?.cpu, 20)
        XCTAssertEqual(h.samples.count, 11)
    }

    func testRecentAndStats() {
        var h = TemperatureHistory(window: 100)
        for (s, c) in [(0, 50.0), (10, 60), (20, 70), (30, 80)] { h.append(sample(Double(s), cpu: c)) }
        let now = t0.addingTimeInterval(30)
        XCTAssertEqual(h.recent(15, now: now).map(\.cpu), [70, 80])
        XCTAssertEqual(h.stats(25, now: now) { $0.cpu }, HistoryStats(min: 60, avg: 70, max: 80))
        XCTAssertNil(h.stats(25, now: now) { $0.gpu })
    }

    func testDownsampleKeepsPeaksAndLatestRPM() {
        var h = TemperatureHistory(window: 1000)
        for s in 0..<100 { h.append(sample(Double(s), cpu: s == 37 ? 95 : 50, gpu: 40, rpm: [Double(s)])) }
        let now = t0.addingTimeInterval(99)
        let d = h.downsampled(1000, now: now, maxPoints: 10)
        XCTAssertLessThanOrEqual(d.count, 11)
        XCTAssertEqual(d.compactMap(\.cpu).max(), 95)       // spike survives
        XCTAssertEqual(d.last?.rpm, [99])
        XCTAssertEqual(d.last?.time, now)
        XCTAssertEqual(h.downsampled(1000, now: now, maxPoints: 500).count, 100)  // no-op when it fits
    }

    func testDownsampleIsStableAsWindowSlides() {
        var h = TemperatureHistory(window: 3600)
        for s in stride(from: 0, through: 1000, by: 2) { h.append(sample(Double(s), cpu: 50 + Double(s % 37))) }
        let before = h.downsampled(600, now: t0.addingTimeInterval(1000), maxPoints: 60)
        h.append(sample(1002, cpu: 99))
        let after = h.downsampled(600, now: t0.addingTimeInterval(1002), maxPoints: 60)
        let interior = before.dropFirst().dropLast()
        XCTAssertFalse(interior.isEmpty)
        let afterByTime = Dictionary(uniqueKeysWithValues: after.map { ($0.time, $0) })
        for p in interior { XCTAssertEqual(afterByTime[p.time], p) }
    }

    func testGaps() {
        var h = TemperatureHistory(window: 1000)
        for s in [0.0, 2, 4, 15, 17] { h.append(sample(s, cpu: 50)) }
        let gaps = h.gaps(longerThan: 8)
        XCTAssertEqual(gaps.count, 1)
        XCTAssertEqual(gaps.first?.from, t0.addingTimeInterval(4))
    }

    func testHottestIgnoresMissing() {
        XCTAssertEqual(sample(0, cpu: nil, gpu: 70).hottest, 70)
        XCTAssertEqual(sample(0, cpu: 80, gpu: 70).hottest, 80)
        XCTAssertNil(sample(0, cpu: nil, gpu: nil).hottest)
    }

    func testProfilePercentMatchesController() {
        XCTAssertNil(Profile.apple.percent(at: 80))
        XCTAssertNil(Profile.quiet.percent(at: nil))
        XCTAssertEqual(Profile.maximum.percent(at: 40), 100)
        XCTAssertEqual(Profile.quiet.percent(at: 85), 35)
        XCTAssertEqual(Profile.quiet.percent(at: FanController.hardLimitC), 100)
        XCTAssertTrue(Profile.legsCool.isCurve)
        XCTAssertFalse(Profile.maximum.isCurve)
    }
}
