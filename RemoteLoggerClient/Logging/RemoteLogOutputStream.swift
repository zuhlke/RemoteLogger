import Foundation
import Logging
import BonjourServices

struct RemoteLogOutputStream: LogOutputStream {
    let remoteLoggerClient: RemoteLoggerClient

    init(remoteLoggerClient: RemoteLoggerClient) {
        self.remoteLoggerClient = remoteLoggerClient
    }

    mutating func write(_ log: LogOutput) {
        let info = LogInfo(
            timestamp: log.timestamp,
            level: log.level.rawValue,
            label: log.label,
            source: log.source,
            message: log.message,
            metadata: log.metadata
        )
        remoteLoggerClient.write(info)
    }

    static func logger(label: String, remoteLoggerClient: RemoteLoggerClient) -> LogHandler {
        LogOutputStreamLogHandler(
            label: label,
            stream: RemoteLogOutputStream(remoteLoggerClient: remoteLoggerClient)
        )
    }
}
