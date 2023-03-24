import Foundation
import Network

protocol BonjourConnectionDelegate: AnyObject {
    func connection(_ connection: BonjourConnection, didChangeState newState: NWConnection.State)
    func connection(_ connection: BonjourConnection, didReceiveEvent event: BonjourConnection.Event)
}

final class BonjourConnection {
    private let connection: NWConnection
    private var buffer = Data()

    weak var delegate: BonjourConnectionDelegate?

    convenience init(endpoint: NWEndpoint) {
        self.init(NWConnection(to: endpoint, using: .tcp))
    }

    init(_ connection: NWConnection) {
        self.connection = connection
    }

    func start(on queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.connection(self, didChangeState: $0)
        }
        receive()
        connection.start(queue: queue)
    }

    enum Event {
        case packet(Packet)
        case error(Error)
        case completed
    }

    struct Packet {
        public let code: UInt8
        public let body: Data
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] data, _, isCompleted, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.process(data: data)
            }
            if isCompleted {
                self.send(event: .completed)
            } else if let error = error {
                self.send(event: .error(error))
            } else {
                self.receive()
            }
        }
    }

    private func process(data freshData: Data) {
        guard !freshData.isEmpty else { return }

        var freshData = freshData
        if buffer.isEmpty {
            while let (packet, size) = decodePacket(from: freshData) {
                send(event: .packet(packet))
                if size == freshData.count {
                    return // No no processing needed
                }
                freshData.removeFirst(size)
            }
        }

        if !freshData.isEmpty {
            buffer.append(freshData)
            while let (packet, size) = decodePacket(from: buffer) {
                send(event: .packet(packet))
                buffer.removeFirst(size)
            }
            if buffer.count == 0 {
                buffer = Data()
            }
        }
    }

    private func decodePacket(from data: Data) -> (Packet, Int)? {
        do {
            let (header, body) = try PacketCode.decode(buffer: data)
            let packet = BonjourConnection.Packet(code: header.code, body: body)
            return (packet, header.totalPacketLength)
        } catch {
            if case .notEnoughData? = error as? PacketParsingError {
                return nil
            }
            return nil
        }
    }

    private func send(event: Event) {
        delegate?.connection(self, didReceiveEvent: event)
    }

    func send(code: UInt8, data: Data, _ completion: ((NWError?) -> Void)? = nil) {
        if let data = try? PacketCode.encode(code: code, body: data) {
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    func send<T: Encodable>(code: UInt8, entity: T, _ completion: ((NWError?) -> Void)? = nil) {
        if let data = try? JSONEncoder().encode(entity) {
            send(code: code, data: data, completion)
        }
    }

    func cancel() {
        connection.cancel()
    }
}

extension BonjourConnection {
    struct Empty: Codable {
        public init() {}
    }

    func send(code: PacketCode, data: Data, _ completion: ((NWError?) -> Void)? = nil) {
        send(code: code.rawValue, data: data, completion)
    }

    func send<T: Encodable>(code: PacketCode, entity: T, _ completion: ((NWError?) -> Void)? = nil) {
        send(code: code.rawValue, entity: entity, completion)
    }

    func send(code: PacketCode, _ completion: ((NWError?) -> Void)? = nil) {
        send(code: code.rawValue, entity: Empty(), completion)
    }
}
