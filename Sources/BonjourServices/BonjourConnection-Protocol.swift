// Portions of this file are modified from Pulse Pro
// (https://github.com/kean/PulsePro) by Alexander Grebenyuk.

import Foundation
import Network

enum BonjourService {
    public static let type = "_ws._tcp"
}

extension NWBrowser.Result {
    var name: String? {
        switch endpoint {
        case .service(let name, _, _, _):
            return name
        default:
            return nil
        }
    }
}

enum PacketCode: UInt8 {
    case clientHello = 0
    case serverHello = 1
    case pause = 2
    case resume = 3
    case message = 4
    case ping = 5

    var description: String {
        switch self {
        case .clientHello: return "PacketCode.clientHello"
        case .serverHello: return "PacketCode.serverHello"
        case .pause: return "PacketCode.pause"
        case .resume: return "PacketCode.resume"
        case .message: return "PacketCode.message"
        case .ping: return "PacketCode.ping"
        }
    }
}

struct PacketClientHello: Codable {
    let deviceId: UUID
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo
}

enum PacketParsingError: Error {
    case notEnoughData
    case unsupportedContentSize
}

// MARK: Helpers

extension PacketCode {
    static func encode(code: UInt8, body: Data) throws -> Data {
        guard body.count < UInt32.max else {
            throw PacketParsingError.unsupportedContentSize
        }

        var data = Data()
        data.append(code)
        data.append(Data(UInt32(body.count)))
        data.append(body)
        return data
    }

    static func decode(buffer: Data) throws -> (PacketHeader, Data) {
        let header = try PacketHeader(data: buffer)
        guard buffer.count >= header.totalPacketLength else {
            throw PacketParsingError.notEnoughData
        }
        let body = buffer.from(header.contentOffset, size: Int(header.contentSize))
        return (header, body)
    }

    /// |code|contentSize|body?|
    struct PacketHeader {
        let code: UInt8
        let contentSize: UInt32

        var totalPacketLength: Int { Int(PacketHeader.size + contentSize) }
        var contentOffset: Int { Int(PacketHeader.size) }

        static let size: UInt32 = 5

        init(code: UInt8, contentSize: UInt32) {
            self.code = code
            self.contentSize = contentSize
        }

        init(data: Data) throws {
            guard data.count >= PacketHeader.size else {
                throw PacketParsingError.notEnoughData
            }
            self.code = data[data.startIndex]
            self.contentSize = UInt32(data.from(1, size: 4))
        }
    }
}

// MARK: - Helpers (Binary Protocol)

// Expects big endian.
extension Data {
    fileprivate init(_ value: UInt32) {
        var contentSize = value.bigEndian
        self.init(bytes: &contentSize, count: MemoryLayout<UInt32>.size)
    }

    fileprivate func from(_ from: Data.Index, size: Int) -> Data {
        self[(from + startIndex) ..< (from + size + startIndex)]
    }
}

extension UInt32 {
    fileprivate init(_ data: Data) {
        self = UInt32(data.parseInt(size: 4))
    }
}

extension Data {
    fileprivate func parseInt(size: Int) -> UInt64 {
        precondition(size > 0 && size <= 8)
        var accumulator: UInt64 = 0
        for i in 0 ..< size {
            let shift = (size - i - 1) * 8
            accumulator |= UInt64(self[self.startIndex + i]) << UInt64(shift)
        }
        return accumulator
    }
}

struct AppInfo: Codable {
    public let bundleIdentifier: String?
    public let name: String?
    public let version: String?
    public let build: String?
}

struct DeviceInfo: Codable {
    public let name: String
    public let model: String
    public let localizedModel: String
    public let systemName: String
    public let systemVersion: String
}

extension AppInfo {
    static var bundleIdentifier: String? { Bundle.main.bundleIdentifier }
    static var appName: String? { Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String }
    static var appVersion: String? { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String }
    static var appBuild: String? { Bundle.main.infoDictionary?["CFBundleVersion"] as? String }
}

extension AppInfo {
    static func make() -> AppInfo {
        return AppInfo(
            bundleIdentifier: AppInfo.bundleIdentifier,
            name: AppInfo.appName,
            version: AppInfo.appVersion,
            build: AppInfo.appBuild
        )
    }
}

#if os(iOS) || os(tvOS)
import UIKit

func getDeviceId() -> UUID {
    UIDevice.current.identifierForVendor ?? getFallbackDeviceId()
}

extension DeviceInfo {
    static func make() -> DeviceInfo {
        let device = UIDevice.current
        return DeviceInfo(
            name: device.name,
            model: device.model,
            localizedModel: device.localizedModel,
            systemName: device.systemName,
            systemVersion: device.systemVersion
        )
    }
}

#elseif os(watchOS)
import WatchKit

@available(watchOS 7.0, *)
func getDeviceId() -> UUID {
    WKInterfaceDevice.current().identifierForVendor ?? getFallbackDeviceId()
}

extension DeviceInfo {
    static func make() -> DeviceInfo {
        let device = WKInterfaceDevice.current()
        return DeviceInfo(
            name: device.name,
            model: device.model,
            localizedModel: device.localizedModel,
            systemName: device.systemName,
            systemVersion: device.systemVersion
        )
    }
}
#else
import AppKit

extension DeviceInfo {
    static func make() -> DeviceInfo {
        return DeviceInfo(
            name: Host.current().name ?? "unknown",
            model: "unknown",
            localizedModel: "unknown",
            systemName: "macOS",
            systemVersion: ProcessInfo().operatingSystemVersionString
        )
    }
}

func getDeviceId() -> UUID {
    return getFallbackDeviceId()
}
#endif

private func getFallbackDeviceId() -> UUID {
    let key = "com.zuhlke.remote_logger_id"

    if let value = UserDefaults.standard.string(forKey: key),
       let uuid = UUID(uuidString: value) {
        return uuid
    } else {
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }
}
