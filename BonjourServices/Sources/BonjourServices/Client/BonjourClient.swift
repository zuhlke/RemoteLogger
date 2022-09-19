import Foundation
import Combine
import Network

public final class BonjourClient {
    private let lock = NSLock()

    let browser = BonjourServiceBrowser()
    let connecter = BonjourClientConnecter()

    private var buffer: [Data] = []
    private var cancellables: Set<AnyCancellable> = .init()

    public init() {
        connecter.isConnected.eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] flag in
                guard let self = self else { return }
                if flag {
                    self.buffer.forEach { self.send(data: $0) }
                    self.buffer = []
                }
            }.store(in: &cancellables)
    }

    public func enable() {
        browser.startBrowsing()
    }

    public func disable() {
        disconnect()
        browser.stopBrowsing()
    }

    public func fetchDevices() -> AnyPublisher<[String], Never> {
        browser.fetchDevices()
    }

    public func isConnected(to server: String) -> AnyPublisher<BonjourClientConnectionState, Never> {
        connecter.selectedServer.combineLatest(connecter.connectionState)
            .map { selectedServer, state -> BonjourClientConnectionState in
                selectedServer != server ? .idle : state
            }
            .eraseToAnyPublisher()
    }

    public func connect(to server: String) {
        guard let server = browser.servers.filter({ $0.name == server }).first else {
            return
        }
        connecter.connect(to: server)
    }

    public func disconnect() {
        connecter.disconnect()
    }

    public func send(data: Data, _ completion: ((NWError?) -> Void)? = nil) {
        lock.lock(); defer { lock.unlock() }
        if connecter.isConnected.value {
            connecter.send(data: data, completion)
        } else {
            buffer.append(data)
        }
    }
}
