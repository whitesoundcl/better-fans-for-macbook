import Foundation
import IOKit

public enum SMCError: Error, CustomStringConvertible {
    case serviceNotFound
    case openFailed(kern_return_t)
    case callFailed(kern_return_t)
    case smcResult(UInt8, key: String)
    case unsupportedType(String)

    public var description: String {
        switch self {
        case .serviceNotFound: return "AppleSMC service not found"
        case .openFailed(let r): return "IOServiceOpen failed (\(r))"
        case .callFailed(let r): return "IOConnectCallStructMethod failed (\(r))"
        case .smcResult(let r, let key): return "SMC returned result \(r) for key \(key)"
        case .unsupportedType(let t): return "Unsupported SMC data type '\(t)'"
        }
    }
}

/// Mirrors the kernel's SMCParamStruct (80 bytes).
struct SMCParamStruct {
    struct Version { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0; var release: UInt16 = 0 }
    struct PLimit { var version: UInt16 = 0, length: UInt16 = 0; var cpu: UInt32 = 0, gpu: UInt32 = 0, mem: UInt32 = 0 }
    struct KeyInfo { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var dataAttributes: UInt8 = 0 }
    typealias Bytes32 = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    var key: UInt32 = 0
    var vers = Version()
    var pLimit = PLimit()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: Bytes32 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

public struct SMCValue {
    public let key: String
    public let type: String
    public let bytes: [UInt8]

    /// Numeric interpretation of the value, nil for types we don't decode.
    public var number: Double? { SMCDecode.number(type: type, bytes: bytes) }
}

public enum SMCDecode {
    public static func number(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let raw = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: raw))
        case "ui8 ": return bytes.first.map(Double.init)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256.0
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        default: return nil
        }
    }

    public static func encodeFloat(_ value: Float) -> [UInt8] {
        let raw = value.bitPattern
        return [UInt8(raw & 0xFF), UInt8((raw >> 8) & 0xFF), UInt8((raw >> 16) & 0xFF), UInt8(raw >> 24)]
    }
}

func fourCC(_ s: String) -> UInt32 {
    s.utf8.prefix(4).reduce(0) { ($0 << 8) | UInt32($1) }
}

func fourCCString(_ v: UInt32) -> String {
    let b = [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    return String(decoding: b, as: UTF8.self)
}

/// Thin wrapper over the AppleSMC IOKit user client. Reading needs no privileges; writing needs root.
public final class SMC {
    private var conn: io_connect_t = 0
    private static let handleYPCEvent: UInt32 = 2
    private enum Cmd { static let readKey: UInt8 = 5, writeKey: UInt8 = 6, keyFromIndex: UInt8 = 8, keyInfo: UInt8 = 9 }

    public init() throws {
        assert(MemoryLayout<SMCParamStruct>.size == 80, "SMCParamStruct layout drifted")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw SMCError.serviceNotFound }
        defer { IOObjectRelease(service) }
        let r = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard r == KERN_SUCCESS else { throw SMCError.openFailed(r) }
    }

    deinit { if conn != 0 { IOServiceClose(conn) } }

    private func call(_ input: inout SMCParamStruct, key: String) throws -> SMCParamStruct {
        var output = SMCParamStruct()
        var outSize = MemoryLayout<SMCParamStruct>.size
        let r = IOConnectCallStructMethod(conn, Self.handleYPCEvent, &input,
                                          MemoryLayout<SMCParamStruct>.size, &output, &outSize)
        guard r == KERN_SUCCESS else { throw SMCError.callFailed(r) }
        guard output.result == 0 else { throw SMCError.smcResult(output.result, key: key) }
        return output
    }

    /// A key's size/type never changes, so look it up once.
    private var keyInfoCache: [String: SMCParamStruct.KeyInfo] = [:]

    private func keyInfo(_ key: String) throws -> SMCParamStruct.KeyInfo {
        if let cached = keyInfoCache[key] { return cached }
        var input = SMCParamStruct()
        input.key = fourCC(key)
        input.data8 = Cmd.keyInfo
        let info = try call(&input, key: key).keyInfo
        keyInfoCache[key] = info
        return info
    }

    public func read(_ key: String) throws -> SMCValue {
        let info = try keyInfo(key)
        var input = SMCParamStruct()
        input.key = fourCC(key)
        input.keyInfo.dataSize = info.dataSize
        input.data8 = Cmd.readKey
        let out = try call(&input, key: key)
        let size = min(Int(info.dataSize), 32)
        let bytes = withUnsafeBytes(of: out.bytes) { Array($0.prefix(size)) }
        return SMCValue(key: key, type: fourCCString(info.dataType), bytes: bytes)
    }

    public func write(_ key: String, bytes: [UInt8]) throws {
        let info = try keyInfo(key)
        var input = SMCParamStruct()
        input.key = fourCC(key)
        input.keyInfo.dataSize = info.dataSize
        input.data8 = Cmd.writeKey
        withUnsafeMutableBytes(of: &input.bytes) { buf in
            for (i, b) in bytes.prefix(32).enumerated() { buf[i] = b }
        }
        _ = try call(&input, key: key)
    }

    public func keyCount() throws -> Int {
        Int(try read("#KEY").number ?? 0)
    }

    public func key(at index: Int) throws -> String {
        var input = SMCParamStruct()
        input.data8 = Cmd.keyFromIndex
        input.data32 = UInt32(index)
        let out = try call(&input, key: "#\(index)")
        return fourCCString(out.key)
    }

    public func allKeys() throws -> [String] {
        let n = try keyCount()
        return (0..<n).compactMap { try? key(at: $0) }
    }
}
