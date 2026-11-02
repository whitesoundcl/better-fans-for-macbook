import Foundation

public enum ProfileMode: Codable, Equatable {
    case auto                      // hand control back to macOS
    case fixed(percent: Double)    // constant speed
    case curve(Curve)              // temperature-driven
}

public struct Profile: Codable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var mode: ProfileMode
    /// Degrees the temperature must fall below the held value before the fans slow down.
    public var hysteresis: Double
    public var rampUpRPMPerSec: Double
    public var rampDownRPMPerSec: Double

    public init(name: String, mode: ProfileMode, hysteresis: Double = 3,
                rampUpRPMPerSec: Double = 800, rampDownRPMPerSec: Double = 250) {
        self.name = name
        self.mode = mode
        self.hysteresis = hysteresis
        self.rampUpRPMPerSec = rampUpRPMPerSec
        self.rampDownRPMPerSec = rampDownRPMPerSec
    }
}

public extension Profile {
    static let apple = Profile(name: "Automático (Apple)", mode: .auto)

    static let legsCool = Profile(name: "Frío para piernas", mode: .curve(Curve(points: [
        .init(temp: 40, percent: 10), .init(temp: 50, percent: 25), .init(temp: 60, percent: 45),
        .init(temp: 70, percent: 65), .init(temp: 80, percent: 85), .init(temp: 90, percent: 100),
    ])))

    static let quiet = Profile(name: "Silencioso", mode: .curve(Curve(points: [
        .init(temp: 50, percent: 0), .init(temp: 65, percent: 20), .init(temp: 75, percent: 45),
        .init(temp: 85, percent: 75), .init(temp: 92, percent: 100),
    ])))

    static let maximum = Profile(name: "Máximo", mode: .fixed(percent: 100))

    static let builtIns: [Profile] = [.apple, .legsCool, .quiet, .maximum]
}

/// Persists user profiles as JSON; built-ins are always available.
public struct ProfileStore {
    public let url: URL

    public init(url: URL = ProfileStore.defaultURL) { self.url = url }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FanBar/profiles.json")
    }

    public func load() -> [Profile] {
        guard let data = try? Data(contentsOf: url),
              let custom = try? JSONDecoder().decode([Profile].self, from: data) else { return Profile.builtIns }
        let customNames = Set(custom.map(\.name))
        return Profile.builtIns.filter { !customNames.contains($0.name) } + custom
    }

    public func save(_ profiles: [Profile]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(profiles).write(to: url, options: .atomic)
    }
}
