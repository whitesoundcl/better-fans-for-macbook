import AppKit
import Foundation
import FanCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [Profile]
    @Published var selectedName: String {
        didSet { UserDefaults.standard.set(selectedName, forKey: "selectedProfile"); poll() }
    }
    @Published var temperature: Double?
    @Published var fans: [FanReading] = []
    @Published var helperStatus: HelperStatus?
    @Published var helperReachable = false
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    private let store = ProfileStore()
    private var smc: SMC?
    private var sensors: SensorReader?
    private var connection: NSXPCConnection?
    private var timer: Timer?

    init() {
        let loaded = ProfileStore().load()
        profiles = loaded
        let saved = UserDefaults.standard.string(forKey: "selectedProfile")
        selectedName = loaded.contains { $0.name == saved } ? saved! : Profile.apple.name
        if let s = try? SMC() {
            smc = s
            sensors = SensorReader(smc: s)
        }
        schedulePolling()
        poll()
    }

    /// Fast while the menu is visible; slow otherwise. Must stay well under the helper's 10 s watchdog.
    var menuOpen = false {
        didSet {
            guard menuOpen != oldValue else { return }
            schedulePolling()
            if menuOpen { poll() }
        }
    }

    private func schedulePolling() {
        timer?.invalidate()
        let interval: TimeInterval = menuOpen ? 2 : 4
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        t.tolerance = interval * 0.25
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Fans are in manual mode but not because of our helper: another app is overriding macOS.
    var otherAppControlling: Bool {
        fans.contains { $0.mode == 1 } && helperStatus?.controlling != true
    }

    var selected: Profile { profiles.first { $0.name == selectedName } ?? .apple }

    var menuBarTitle: String {
        let t = temperature.map { String(format: "%.0f°", $0) } ?? "–"
        guard let rpm = fans.map(\.actualRPM).max(), rpm > 0 else { return t }
        return "\(t) \(Int(rpm))"
    }

    func update(_ profile: Profile) {
        if let i = profiles.firstIndex(where: { $0.name == profile.name }) { profiles[i] = profile } else { profiles.append(profile) }
        try? store.save(profiles.filter { !Profile.builtIns.contains($0) })
        poll()
    }

    func poll() {
        // The helper already reads every sensor each tick; only do it here when it isn't running.
        if helperReachable, let t = helperStatus?.temperature { temperature = t } else { temperature = sensors?.hottest() }
        fans = sensors?.fans() ?? []
        sendProfile()
    }

    func resetToAuto() {
        remote()?.resetToAuto { _ in }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: XPC

    private func remote() -> FanHelperProtocol? {
        if connection == nil {
            let c = NSXPCConnection(machServiceName: fanHelperMachName, options: .privileged)
            c.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)
            c.invalidationHandler = { [weak self] in Task { @MainActor in self?.connection = nil; self?.helperReachable = false } }
            c.interruptionHandler = { [weak self] in Task { @MainActor in self?.helperReachable = false } }
            c.resume()
            connection = c
        }
        return connection?.remoteObjectProxyWithErrorHandler { [weak self] _ in
            Task { @MainActor in self?.helperReachable = false; self?.helperStatus = nil }
        } as? FanHelperProtocol
    }

    private func sendProfile() {
        guard let data = try? JSONEncoder().encode(selected) else { return }
        remote()?.apply(profile: data) { [weak self] reply in
            let status = try? JSONDecoder().decode(HelperStatus.self, from: reply)
            Task { @MainActor in
                self?.helperReachable = status != nil
                self?.helperStatus = status
            }
        }
    }
}
