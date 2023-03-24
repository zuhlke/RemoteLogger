import Foundation

public struct LogInfo: Codable, Identifiable {
    public let id: UUID
    public let timestamp: String
    public let level: String
    public let label: String
    public let source: String
    public let message: String
    public let metadata: String

    public init(
        timestamp: String,
        level: String,
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

    public func string() -> String {
        return "\(timestamp) \(level) \(label) :\(metadata) [\(source)] \(message)\n"
    }
}
