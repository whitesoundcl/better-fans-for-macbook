import AppKit
import Foundation
import FanCore
import OSLog
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [Profile]
    @Published var selectedName: String {
        didSet {
            guard selectedName != oldValue else { return }
            if !isPreview { UserDefaults.standard.set(selectedName, forKey: "selectedProfile") }
            sendProfile()
        }
    }
    @Published var cpuTemp: Double?
    @Published var gpuTemp: Double?
    /// Air inside the chassis (`TAOL` on M5 Pro), shown as "ambiente": above room temperature.
    @Published var ambientTemp: Double?
    /// Degrees added to `ambientTemp` for display so it matches a room thermometer; 0 = not calibrated.
    @Published var ambientOffset: Double {
        didSet {
            guard ambientOffset != oldValue, !isPreview else { return }
            UserDefaults.standard.set(ambientOffset, forKey: "ambientOffset")
        }
    }
    @Published var fans: [FanReading] = []
    @Published var helperStatus: HelperStatus?
    @Published var helperReachable = false
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published var loginItemError: String?
    /// Set when writing profiles.json fails, so an edit isn't silently lost.
    @Published var saveError: String?

    let history = HistoryStore()

    private let store = ProfileStore()
    private let sampler = Sampler()
    private let log = Logger(subsystem: "com.whitesound.betterfans", category: "poll")
    private var connection: NSXPCConnection?
    private var pollTask: Task<Void, Never>?
    private var lastPoll: Date?
    private var pendingSave: Task<Void, Never>?
    private var pendingSend: Task<Void, Never>?
    private let isPreview: Bool

    /// Must stay well under the helper's 10 s watchdog; also the history resolution.
    static let pollInterval: TimeInterval = 2

    init(preview: Bool = false) {
        isPreview = preview
        let loaded = preview ? Profile.builtIns : ProfileStore().load()
        profiles = loaded
        let saved = preview ? nil : UserDefaults.standard.string(forKey: "selectedProfile")
        selectedName = if let saved, loaded.contains(where: { $0.name == saved }) { saved } else { Profile.apple.name }
        ambientOffset = preview ? 0 : UserDefaults.standard.double(forKey: "ambientOffset")
        guard !preview else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.poll()
                try? await Task.sleep(for: .seconds(Self.pollInterval))
            }
        }
    }

    // MARK: Derived state

    /// Ambient reading as shown to the user, with the calibration applied.
    var ambientDisplay: Double? { AmbientCalibration.apply(ambientOffset, to: ambientTemp) }

    /// Raw sensor value used for calibrating: the last two minutes' average, so one noisy sample
    /// doesn't set the offset.
    var ambientForCalibration: Double? {
        history.history.stats(120, now: .now) { $0.ambient }?.avg ?? ambientTemp
    }

    func calibrateAmbient(room: Double) {
        guard let sensor = ambientForCalibration else { return }
        ambientOffset = AmbientCalibration.offset(room: room, sensor: sensor)
    }

    /// What the curve reacts to: the hottest CPU or GPU sensor.
    var temperature: Double? {
        if helperReachable, let t = helperStatus?.temperature { return t }
        return [cpuTemp, gpuTemp].compactMap { $0 }.max()
    }

    /// Fans are in manual mode but not because of our helper: another app is overriding macOS.
    var otherAppControlling: Bool {
        fans.contains { $0.mode == 1 } && helperStatus?.controlling != true
    }

    var selected: Profile { profiles.first { $0.name == selectedName } ?? .apple }

    var menuBarTitle: String {
        temperature.map { "\($0.formatted(.number.precision(.fractionLength(0))))°" } ?? "–°"
    }

    /// Speed the selected profile asks for right now, as % of each fan's range.
    var targetPercent: Double? { selected.percent(at: temperature) }

    func isBuiltIn(_ name: String) -> Bool { Profile.builtIns.contains { $0.name == name } }

    /// A built-in profile the user has edited (stored as a same-name override).
    func isModifiedBuiltIn(_ p: Profile) -> Bool {
        guard let original = Profile.builtIns.first(where: { $0.name == p.name }) else { return false }
        return original != p
    }

    // MARK: Profiles

    /// Updates in memory at once; disk write and helper update are coalesced so dragging
    /// a curve point doesn't hit the disk and the SMC on every mouse event.
    func update(_ profile: Profile) {
        if let i = profiles.firstIndex(where: { $0.name == profile.name }) { profiles[i] = profile } else { profiles.append(profile) }
        scheduleSave()
        if profile.name == selectedName { scheduleSend() }
    }

    /// Copies `profile` under a free name based on `name` and selects it.
    func duplicate(_ profile: Profile, as name: String) {
        let base = name.trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { return }
        var candidate = base, n = 2
        while profiles.contains(where: { $0.name == candidate }) { candidate = "\(base) \(n)"; n += 1 }
        var p = profile
        p.name = candidate
        update(p)
        selectedName = candidate
    }

    /// Removes a custom profile, or restores a built-in one to its original values.
    func delete(_ name: String) {
        if let original = Profile.builtIns.first(where: { $0.name == name }) {
            update(original)
        } else {
            profiles.removeAll { $0.name == name }
            if selectedName == name { selectedName = Profile.apple.name }
            scheduleSave()
        }
    }

    private func scheduleSave() {
        guard !isPreview else { return }
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Writes a pending profile edit now (used before quitting, so the last change isn't lost).
    func flushSave() {
        guard let pending = pendingSave else { return }
        pending.cancel()
        pendingSave = nil
        saveNow()
    }

    private func saveNow() {
        do {
            try store.save(profiles.filter { !Profile.builtIns.contains($0) })
            setIfChanged(\.saveError, nil)
        } catch {
            saveError = "No se pudieron guardar los perfiles: \(error.localizedDescription)"
        }
    }

    private func scheduleSend() {
        pendingSend?.cancel()
        pendingSend = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.sendProfile()
        }
    }

    // MARK: Polling

    func poll() async {
        let now = Date.now
        if let last = lastPoll, now.timeIntervalSince(last) > 8 {
            // A stall this long risks the helper's 10 s watchdog handing fans back to macOS.
            log.warning("poll gap \(now.timeIntervalSince(last), format: .fixed(precision: 1)) s")
        }
        lastPoll = now
        sendProfile()  // also the helper's heartbeat
        let r = await sampler.read()
        setIfChanged(\.cpuTemp, r.cpu)
        setIfChanged(\.gpuTemp, r.gpu)
        setIfChanged(\.ambientTemp, r.ambient)
        setIfChanged(\.fans, r.fans)
        history.append(HistorySample(time: now, cpu: r.cpu, gpu: r.gpu, rpm: r.fans.map(\.actualRPM), ambient: r.ambient))
    }

    /// `@Published` notifies on every assignment, even of an equal value; skipping those avoids
    /// redrawing every view that observes the model twice per poll.
    private func setIfChanged<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<AppModel, T>, _ value: T) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }

    func resetToAuto() {
        remote()?.resetToAuto { _ in }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginItemError = nil
        } catch {
            loginItemError = "No se pudo cambiar «Abrir al iniciar sesión»: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Toggle binding target: writes go through `setLaunchAtLogin` so failures surface in the menu.
    var launchAtLoginSetting: Bool {
        get { launchAtLogin }
        set { setLaunchAtLogin(newValue) }
    }

    // MARK: Live bindings for the editor
    //
    // Views bind to these (`$model.selectedCurvePoints`) instead of building `Binding(get:set:)`
    // around a profile captured in `body`: a captured getter goes stale between two writes in the
    // same event, which silently dropped the first write (e.g. a point's temperature while dragging).

    var selectedCurvePoints: [CurvePoint] {
        get { if case .curve(let c) = selected.mode { c.points } else { [] } }
        set { var p = selected; p.mode = .curve(Curve(points: newValue)); update(p) }
    }

    var selectedHysteresis: Double {
        get { selected.hysteresis }
        set { var p = selected; p.hysteresis = newValue; update(p) }
    }

    var selectedRampUp: Double {
        get { selected.rampUpRPMPerSec }
        set { var p = selected; p.rampUpRPMPerSec = newValue; update(p) }
    }

    var selectedRampDown: Double {
        get { selected.rampDownRPMPerSec }
        set { var p = selected; p.rampDownRPMPerSec = newValue; update(p) }
    }

    // MARK: XPC

    private func remote() -> FanHelperProtocol? {
        guard !isPreview else { return nil }
        if connection == nil {
            let c = NSXPCConnection(machServiceName: fanHelperMachName, options: .privileged)
            c.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)
            c.invalidationHandler = { [weak self] in Task { @MainActor in self?.connection = nil; self?.applyHelperReply(nil) } }
            c.interruptionHandler = { [weak self] in Task { @MainActor in self?.setIfChanged(\.helperReachable, false) } }
            c.resume()
            connection = c
        }
        return connection?.remoteObjectProxyWithErrorHandler { [weak self] _ in
            Task { @MainActor in self?.applyHelperReply(nil) }
        } as? FanHelperProtocol
    }

    private func sendProfile() {
        guard let data = try? JSONEncoder().encode(selected) else { return }
        remote()?.apply(profile: data) { [weak self] reply in
            let status = try? JSONDecoder().decode(HelperStatus.self, from: reply)
            Task { @MainActor in self?.applyHelperReply(status) }
        }
    }

    private func applyHelperReply(_ status: HelperStatus?) {
        setIfChanged(\.helperReachable, status != nil)
        setIfChanged(\.helperStatus, status)
    }

    // MARK: Preview (snapshots)

    /// Fixed sample state for `--snapshot`: no SMC, no helper, no polling.
    static func preview(selected: String = Profile.quiet.name, helper: Bool = true) -> AppModel {
        let m = AppModel(preview: true)
        m.selectedName = selected
        m.cpuTemp = 84.6
        m.gpuTemp = 71.9
        m.ambientTemp = 29.8
        let controlling = helper && selected != Profile.apple.name
        m.helperReachable = helper
        m.helperStatus = helper ? HelperStatus(controlling: controlling, profile: selected, temperature: 84.6, lastError: nil) : nil
        let mode = controlling ? 1 : 0
        m.fans = [
            FanReading(index: 0, actualRPM: 3912, targetRPM: 3920, minRPM: 2317, maxRPM: 7826, mode: mode),
            FanReading(index: 1, actualRPM: 4087, targetRPM: 3920, minRPM: 2317, maxRPM: 7826, mode: mode),
        ]
        let now = Date.now
        for i in stride(from: 1800, through: 4, by: -4) {
            let t = Double(1800 - i)
            let load = 0.5 + 0.5 * sin(t / 260) + (i < 420 && i > 240 ? 0.35 : 0)
            let cpu = 58 + 26 * load + 3 * sin(t / 9)
            let gpu = 52 + 18 * max(0, sin(t / 400)) + 1.5 * sin(t / 13)
            let rpm = 2317 + max(0, (cpu - 65) / 33) * 3500
            let ambient = 28.5 + 1.5 * load
            m.history.append(HistorySample(time: now.addingTimeInterval(-Double(i)), cpu: cpu, gpu: gpu, rpm: [rpm, rpm * 1.04], ambient: ambient))
        }
        m.history.append(HistorySample(time: now, cpu: m.cpuTemp, gpu: m.gpuTemp, rpm: m.fans.map(\.actualRPM), ambient: m.ambientTemp))
        return m
    }
}
