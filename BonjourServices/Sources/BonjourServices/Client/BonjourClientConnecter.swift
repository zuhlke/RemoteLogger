import Foundation
import Network
import Combine

public enum BonjourClientConnectionState {
    case idle, connecting, connected
}

final class BonjourClientConnecter: BonjourConnectionDelegate {
    private let queue = DispatchQueue(label: "BonjourServiceConnecter-queue")

    private var connection: BonjourConnection?
    private var connectedServer: NWBrowser.Result?
    private(set) var selectedServer: CurrentValueSubject<String, Never> = .init("")
    private(set) var connectionState: CurrentValueSubject<BonjourClientConnectionState, Never> = .init(.idle)

    private var connectionRetryItem: DispatchWorkItem?
    private var timeoutDisconnectItem: DispatchWorkItem?
    private var pingItem: DispatchWorkItem?

    var isConnected: CurrentValueSubject<Bool, Never> = .init(false)

    init() {}

    func connect(to server: NWBrowser.Result) {
        selectedServer.value = server.name!
        queue.async { self._connect(to: server) }
    }

    func disconnect() {
        connectionState.value = .idle // The order is important
        connectedServer = nil
        selectedServer.value = ""

        connection?.cancel()
        connection = nil

        connectionRetryItem?.cancel()
        connectionRetryItem = nil

        cancelPingPong()
    }

    func send(data: Data, _ completion: ((NWError?) -> Void)? = nil) {
        connection?.send(code: PacketCode.message.rawValue, data: data, completion)
    }

    private func _connect(to server: NWBrowser.Result) {
        switch connectionState.value {
        case .idle:
            openConnection(to: server)
        case .connecting, .connected:
            guard connectedServer != server else { return }
            disconnect()
            openConnection(to: server)
        }
    }

    private func openConnection(to server: NWBrowser.Result) {
        connectedServer = server
        connectionState.value = .connecting
        let connection = BonjourConnection(endpoint: server.endpoint)
        connection.delegate = self
        connection.start(on: queue)
        self.connection = connection
    }

    private func cancelPingPong() {
        timeoutDisconnectItem?.cancel()
        timeoutDisconnectItem = nil

        pingItem?.cancel()
        pingItem = nil
    }

    func connection(_ connection: BonjourConnection, didChangeState newState: NWConnection.State) {
        guard connectionState.value != .idle else { return }
        switch newState {
        case .ready: handshakeWithServer()
        case .failed: scheduleConnectionRetry()
        default: break
        }
    }

    private func handshakeWithServer() {
        assert(connection != nil)
        // Say "hello" to the server and share information about the client
        let body = PacketClientHello(deviceId: getDeviceId(), deviceInfo: .make(), appInfo: .make())
        connection?.send(code: .clientHello, entity: body)

        // Set timeout and retry in case there was no response from the server
        queue.asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            guard let self = self else { return } // Failed to connect in 10 sec

            guard self.connectionState.value == .connecting else { return }
            self.scheduleConnectionRetry()
        }
    }

    private func scheduleConnectionRetry() {
        guard connectionState.value != .idle, connectionRetryItem == nil else { return }

        cancelPingPong()

        connectionState.value = .connecting

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.connectionRetryItem = nil
            guard self.connectionState.value == .connecting,
                  let server = self.connectedServer else { return }
            self.openConnection(to: server)
        }
        queue.asyncAfter(deadline: .now() + .seconds(2), execute: item)
        connectionRetryItem = item
    }

    func connection(_ connection: BonjourConnection, didReceiveEvent event: BonjourConnection.Event) {
        guard connectionState.value != .idle else { return }

        switch event {
        case .packet(let packet): didReceiveMessage(packet: packet)
        case .error: scheduleConnectionRetry()
        case .completed: break
        }
    }

    private func didReceiveMessage(packet: BonjourConnection.Packet) {
        let code = PacketCode(rawValue: packet.code)

        switch code {
        case .serverHello:
            guard connectionState.value != .connected else { return }
            connectionState.value = .connected
            isConnected.value = true
            schedulePing()
        case .pause:
            isConnected.value = false
        case .resume:
            isConnected.value = true
        case .ping:
            scheduleAutomaticDisconnect()
        default:
            assertionFailure("A packet with an invalid code received from the server: \(packet.code.description)")
        }
    }

    private func schedulePing() {
        connection?.send(code: .ping)
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.connectionState.value == .connected else { return }
            self.schedulePing()
        }
        queue.asyncAfter(deadline: .now() + .seconds(2), execute: item)
        pingItem = item
    }

    private func scheduleAutomaticDisconnect() {
        timeoutDisconnectItem?.cancel()

        guard connectionState.value == .connected else { return }

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.connectionState.value == .connected else { return }
            // Haven't received pings from a server in a while, disconnecting
            self.scheduleConnectionRetry()
        }
        queue.asyncAfter(deadline: .now() + .seconds(4), execute: item)
        timeoutDisconnectItem = item
    }
}
