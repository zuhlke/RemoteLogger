import Foundation
import Combine

public enum RemoteLogsConnectionState {
    case idle, connecting, connected
}

public final class RemoteLoggerClient {
    public static let shared = RemoteLoggerClient()

    private let client = BonjourClient()
    public var isEnabled: Bool = false

    init() {}

    public func enable() {
        isEnabled = true
        client.enable()
    }

    public func disable() {
        isEnabled = false
        client.disable()
    }

    public func fetchDevices() -> AnyPublisher<[String], Never> {
        client.fetchDevices()
    }

    public func isConnected(to server: String) -> AnyPublisher<RemoteLogsConnectionState, Never> {
        client.isConnected(to: server).map {
            switch $0 {
            case .idle: return .idle
            case .connected: return .connected
            case .connecting: return .connecting
            }
        }.eraseToAnyPublisher()
    }

    public func connect(to server: String) {
        client.connect(to: server)
    }

    public func disconnect() {
        client.disconnect()
    }

    public func write(_ info: LogInfo) {
        let data = try! JSONEncoder().encode(info)
        client.send(data: data)
    }
}
