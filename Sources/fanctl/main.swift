import Foundation
import FanCore

func usage() -> Never {
    print("""
    usage: fanctl <command>
      dump     list fan (F*) and temperature (T*) SMC keys with values (read-only)
      status   summary of fans and hottest sensors (read-only)
      set <rpm> [seconds]   (root) hold all fans at <rpm> for [seconds] (default 30), then restore automatic
      auto     (root) restore automatic fan control
    """)
    exit(2)
}

func fmt(_ v: SMCValue) -> String {
    if let n = v.number { return String(format: "%.2f", n) }
    return v.bytes.map { String(format: "%02x", $0) }.joined()
}

do {
    let smc = try SMC()
    switch CommandLine.arguments.dropFirst().first {
    case "dump":
        let keys = try smc.allKeys()
        print("total keys: \(keys.count)")
        for k in keys where k.hasPrefix("F") || k.hasPrefix("T") {
            guard let v = try? smc.read(k) else { continue }
            print("\(k)  \(v.type)  \(fmt(v))")
        }
    case "status":
        let n = Int((try? smc.read("FNum"))?.number ?? 0)
        print("fans: \(n)")
        for i in 0..<n {
            let get = { (s: String) in (try? smc.read("F\(i)\(s)"))?.number }
            print("fan \(i): actual \(get("Ac").map { String(Int($0)) } ?? "?") rpm, min \(get("Mn").map { String(Int($0)) } ?? "?"), max \(get("Mx").map { String(Int($0)) } ?? "?"), target \(get("Tg").map { String(Int($0)) } ?? "?"), mode \(get("Md").map { String(Int($0)) } ?? "?")")
        }
        let temps = try smc.allKeys().filter { $0.hasPrefix("T") }.compactMap { k -> (String, Double)? in
            guard let n = (try? smc.read(k))?.number, n > 0, n < 150 else { return nil }
            return (k, n)
        }.sorted { $0.1 > $1.1 }
        print("hottest sensors:")
        for (k, t) in temps.prefix(8) { print(String(format: "  %@  %.1f °C", k, t)) }
    case "set":
        let args = CommandLine.arguments
        guard args.count >= 3, let rpm = Double(args[2]) else { usage() }
        let seconds = args.count >= 4 ? (Double(args[3]) ?? 30) : 30
        guard geteuid() == 0 else { throw SMCError.smcResult(0xFE, key: "run with sudo") }
        let driver = FanDriver(smc: smc)
        // Always hand control back, even on Ctrl-C / kill.
        var sources: [DispatchSourceSignal] = []
        for sig in [SIGINT, SIGTERM, SIGHUP] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .global())
            src.setEventHandler { driver.restoreAuto(); print("\nrestored automatic control"); exit(0) }
            src.resume()
            sources.append(src)
        }
        defer { driver.restoreAuto() }
        try driver.enableManual()
        for i in 0..<driver.fanCount { try driver.setRPM(fan: i, rpm: rpm) }
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 2)
            let row = (0..<driver.fanCount).map { i -> String in
                let ac = (try? smc.read("F\(i)Ac"))?.number ?? 0
                let tg = (try? smc.read("F\(i)Tg"))?.number ?? 0
                return "fan\(i) actual \(Int(ac)) / target \(Int(tg)) mode \(driver.mode(fan: i) ?? -1)"
            }
            print(row.joined(separator: "   "))
        }
        _ = sources
    case "auto":
        guard geteuid() == 0 else { throw SMCError.smcResult(0xFE, key: "run with sudo") }
        FanDriver(smc: smc).restoreAuto()
        print("automatic control restored")
    default:
        usage()
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
