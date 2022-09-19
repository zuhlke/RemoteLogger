import Foundation
import Network

public protocol BonjourServerDelegate: AnyObject {
    func didReceiveMessage(data: Data)
}

public final class BonjourServer: BonjourServerMessageDelegate, BonjourListenerDelegate {
    let connecter = BonjourServerConnecter()
    let listener = BonjourListener()

    public weak var delegate: BonjourServerDelegate?

    public init() {
        connecter.delegate = self
        listener.delegate = self
    }

    public func startListening() {
        listener.startListenser()
    }

    func didReceivePacket(_ packet: BonjourConnection.Packet, for connection: BonjourConnection) {
        connecter.receivePacket(packet, for: connection)
    }

    public func didReceiveMessage(data: Data) {
        delegate?.didReceiveMessage(data: data)
    }
}
