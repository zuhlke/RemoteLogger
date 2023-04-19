// Portions of this file are modified from Pulse Pro
// (https://github.com/kean/PulsePro) by Alexander Grebenyuk.

import Foundation
import Network

protocol BonjourServerMessageDelegate: AnyObject {
    func didReceiveMessage(data: Data)
}

final class BonjourServerConnecter {
    private var clients: [BonjourServerClientId: BonjourServerClient] = [:]

    weak var delegate: BonjourServerMessageDelegate?

    init() {}

    func receivePacket(_ packet: BonjourConnection.Packet, for connection: BonjourConnection) {
        let code = PacketCode(rawValue: packet.code)
        let client = clients.values.first { $0.connection === connection }

        switch code {
        case .clientHello:
            if let request = try? JSONDecoder().decode(PacketClientHello.self, from: packet.body) {
                self.clientDidConnect(connection: connection, request: request)
            }
        case .message: delegate?.didReceiveMessage(data: packet.body)
        case .ping: client?.didReceivePing()
        default: break
        }
    }

    private func clientDidConnect(connection: BonjourConnection, request: PacketClientHello) {
        let clientId = BonjourServerClientId(request: request)
        if let client = clients[clientId] {
            client.connection = connection
            client.didConnectExistingClient()
        } else {
            if let client = try? BonjourServerClient(info: .init(info: request)) {
                client.connection = connection
                clients[clientId] = client
            }
        }
        connection.send(code: .serverHello)
    }
}
