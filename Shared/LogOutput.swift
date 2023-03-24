import Logging
import SwiftUI
import Foundation

public struct LogOutput: Codable {
    public typealias Level = Logger.Level

    public let id: UUID
    public let timestamp: String
    public let level: Level
    public let label: String
    public let source: String
    public let message: String
    public let metadata: String

    public init(
        timestamp: String,
        level: Logger.Level,
        label: String,
        source: String,
        message: String,
        metadata: String
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.level = level
        self.label = label
        self.source = source
        self.message = message
        self.metadata = metadata
    }

    public func json() -> String {
        String(data: try! JSONEncoder().encode(self), encoding: .utf8)!
    }

    public func string() -> String {
        return "\(timestamp) \(level) \(label) :\(metadata) [\(source)] \(message)\n"
    }
}
