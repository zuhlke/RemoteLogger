import Foundation
import Combine
import SwiftUI

public final class RemoteLoggerServer: ObservableObject, BonjourServerDelegate {
    public static let shared = RemoteLoggerServer()

    @Published public var logs: [LogInfo] = []

    private let server = BonjourServer()

    public init() {
        server.delegate = self
    }

    public func didReceiveMessage(data: Data) {
        let logInfo = try! JSONDecoder().decode(LogInfo.self, from: data)
        self.logs.append(logInfo)
    }

    public func read() -> AnyPublisher<[LogInfo], Never> {
        $logs.eraseToAnyPublisher()
    }

    public func startListening() {
        server.startListening()
    }
}
