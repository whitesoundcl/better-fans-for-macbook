import Foundation

public let fanHelperMachName = "com.whitesound.fanbar.helper"

/// XPC interface of the privileged helper. Payloads are JSON `Data` to keep the NSXPC surface trivial.
@objc public protocol FanHelperProtocol {
    /// Sets the active profile (idempotent) and counts as a heartbeat. Replies with an encoded `HelperStatus`.
    func apply(profile: Data, reply: @escaping (Data) -> Void)
    /// Hands control back to macOS immediately.
    func resetToAuto(reply: @escaping (Bool) -> Void)
}

public struct HelperStatus: Codable, Equatable {
    public var controlling: Bool      // true while fans are in manual mode driven by us
    public var profile: String?
    public var temperature: Double?
    public var lastError: String?

    public init(controlling: Bool, profile: String?, temperature: Double?, lastError: String?) {
        self.controlling = controlling
        self.profile = profile
        self.temperature = temperature
        self.lastError = lastError
    }
}

/// If the app stops talking to the helper for this long, the helper returns the fans to macOS.
public let helperWatchdogSeconds: TimeInterval = 10
