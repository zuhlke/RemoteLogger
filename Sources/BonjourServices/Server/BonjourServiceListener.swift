// Portions of this file are modified from Pulse Pro
// (https://github.com/kean/PulsePro) by Alexander Grebenyuk.

import Foundation
import Combine
import Network

struct ConnectionId: Hashable {
    let id: ObjectIdentifier

    init(_ connection: BonjourConnection) {
        self.id = ObjectIdentifier(connection)
    }
}

protocol BonjourListenerDelegate: AnyObject {
    func didReceivePacket(_ packet: BonjourConnection.Packet, for connection: BonjourConnection)
}

public final class BonjourListener: BonjourConnectionDelegate {
    private var isStarted = false
    private var listener: NWListener?

    @Published private var connections: [ConnectionId: BonjourConnection] = [:]

    weak var delegate: BonjourListenerDelegate?

    public init() {}

    func startListenser() {
        guard !isStarted else { return }
        isStarted = true

        do {
            let listener: NWListener
            listener = try NWListener(using: .tcp, on: .any)

            listener.service = NWListener.Service(type: BonjourService.type)
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    self?.scheduleListenerRetry()
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.didReceiveNewConnection(connection)
            }
            listener.start(queue: .main)

            self.listener = listener
        } catch {
            scheduleListenerRetry() // This should never happen
        }
    }

    private func scheduleListenerRetry() {
        guard isStarted else { return }

        // Automatically retry until the user cancels
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
            self?.startListenser()
        }
    }

    private func didReceiveNewConnection(_ connection: NWConnection) {
        let connection = BonjourConnection(connection)
        connection.delegate = self
        connection.start(on: .main)
        let id = ConnectionId(connection)
        connections[id] = connection
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(15)) { [weak self] in
            self?.connections[id] = nil
        }
    }

    func connection(_ connection: BonjourConnection, didChangeState newState: NWConnection.State) {
        switch newState {
        case .failed, .cancelled: connections[ConnectionId(connection)] = nil
        default: break
        }
    }

    func connection(_ connection: BonjourConnection, didReceiveEvent event: BonjourConnection.Event) {
        switch event {
        case .packet(let packet): delegate?.didReceivePacket(packet, for: connection)
        case .error: break
        case .completed: break
        }
    }
}
