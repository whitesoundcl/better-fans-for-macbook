import Foundation
import FanCore

/// All state lives on `queue`; XPC handlers and the timer both hop onto it.
final class Engine {
    private let queue = DispatchQueue(label: "fanhelper.engine")
    private let driver: FanDriver
    private let sensors: SensorReader
    private var controller = FanController(profile: .apple)
    private var lastBeat = Date.distantPast
    private var lastTick = Date()
    private var controlling = false
    private var lastError: String?
    private var lastTemp: Double?
    private var timer: DispatchSourceTimer?

    init(smc: SMC) {
        driver = FanDriver(smc: smc)
        sensors = SensorReader(smc: smc)
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1, repeating: 2, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    func apply(profile: Profile, reply: @escaping (HelperStatus) -> Void) {
        queue.async {
            self.lastBeat = Date()
            if profile != self.controller.profile { self.controller.setProfile(profile) }
            self.tick()
            reply(self.status())
        }
    }

    func resetToAuto(reply: @escaping (Bool) -> Void) {
        queue.async {
            self.controller.setProfile(.apple)
            self.releaseControl()
            reply(true)
        }
    }

    func shutdown() {
        queue.sync { releaseControl() }
    }

    private func status() -> HelperStatus {
        HelperStatus(controlling: controlling, profile: controller.profile.name, temperature: lastTemp, lastError: lastError)
    }

    private func releaseControl() {
        driver.restoreAuto()
        controlling = false
        controller.reset()
    }

    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now

        // Watchdog: app gone (crash, quit, kill) → give fans back to macOS.
        guard now.timeIntervalSince(lastBeat) <= helperWatchdogSeconds else {
            if controlling { releaseControl() }
            return
        }

        lastTemp = sensors.hottest()
        let decision = controller.decide(temp: lastTemp, fans: driver.allLimits, dt: dt)
        switch decision {
        case .auto:
            if controlling { releaseControl() }
        case .rpm:
            do {
                try driver.apply(decision)
                controlling = true
                lastError = nil
            } catch {
                lastError = "\(error)"
                releaseControl()
            }
        }
    }
}

final class Delegate: NSObject, NSXPCListenerDelegate, FanHelperProtocol {
    let engine: Engine
    init(engine: Engine) { self.engine = engine }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection conn: NSXPCConnection) -> Bool {
        // Only the logged-in console user (or root) may drive the fans.
        var st = stat()
        guard stat("/dev/console", &st) == 0,
              conn.effectiveUserIdentifier == st.st_uid || conn.effectiveUserIdentifier == 0 else { return false }
        conn.exportedInterface = NSXPCInterface(with: FanHelperProtocol.self)
        conn.exportedObject = self
        conn.resume()
        return true
    }

    func apply(profile: Data, reply: @escaping (Data) -> Void) {
        guard let p = try? JSONDecoder().decode(Profile.self, from: profile) else {
            reply(Data()); return
        }
        engine.apply(profile: p) { status in reply((try? JSONEncoder().encode(status)) ?? Data()) }
    }

    func resetToAuto(reply: @escaping (Bool) -> Void) { engine.resetToAuto(reply: reply) }
}

do {
    let engine = Engine(smc: try SMC())
    let delegate = Delegate(engine: engine)

    var sources: [DispatchSourceSignal] = []
    for sig in [SIGTERM, SIGINT, SIGHUP] {
        signal(sig, SIG_IGN)
        let s = DispatchSource.makeSignalSource(signal: sig, queue: .global())
        s.setEventHandler { engine.shutdown(); exit(0) }
        s.resume()
        sources.append(s)
    }

    engine.start()
    let listener = NSXPCListener(machServiceName: fanHelperMachName)
    listener.delegate = delegate
    listener.resume()
    RunLoop.main.run()
} catch {
    FileHandle.standardError.write(Data("fanhelperd: \(error)\n".utf8))
    exit(1)
}
