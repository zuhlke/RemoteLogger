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

public protocol LogOutputStream {
    mutating func write(_ log: LogOutput)
}

// https://github.com/apple/swift-log/blob/main/Sources/Logging/Logging.swift
public struct LogOutputStreamLogHandler: LogHandler {
    #if compiler(>=5.6)
    internal typealias _SendableTextOutputStream = LogOutputStream & Sendable
    #else
    internal typealias _SendableTextOutputStream = LogOutputStream
    #endif

    private let stream: _SendableTextOutputStream
    private let label: String

    public var logLevel: Logger.Level = .info

    private var prettyMetadata: String?
    public var metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self.metadata)
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    // internal for testing only
    internal init(label: String, stream: _SendableTextOutputStream) {
        self.label = label
        self.stream = stream
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true
            ? self.prettyMetadata
            : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))

        var stream = self.stream
        stream.write(
            LogOutput(
                timestamp: self.timestamp(),
                level: level,
                label: label,
                source: source,
                message: message.description,
                metadata: "\(prettyMetadata.map { "\($0)" } ?? "")"
            )
        )
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        return !metadata.isEmpty
            ? metadata.lazy.sorted(by: { $0.key < $1.key }).map { "\($0)=\($1)" }.joined(separator: " ")
            : nil
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        #if os(Windows)
        var timestamp: __time64_t = __time64_t()
        _ = _time64(&timestamp)

        var localTime: tm = tm()
        _ = _localtime64_s(&localTime, &timestamp)

        _ = strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", &localTime)
        #else
        var timestamp = time(nil)
        let localTime = localtime(&timestamp)
        strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
        #endif
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
}
