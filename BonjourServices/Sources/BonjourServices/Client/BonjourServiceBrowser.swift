import Foundation
import Network
import Combine

final class BonjourServiceBrowser {
    private let queue = DispatchQueue(label: "BonjourServiceBrowser-queue")

    private var isStarted = false
    private var browser: NWBrowser?

    @Published private(set) var servers: Set<NWBrowser.Result> = []
    private var isEnabled: Bool = false

    init() {}

    func startBrowsing() {
        isEnabled = true
        queue.async(execute: startBrowser)
    }

    func stopBrowsing() {
        isEnabled = false
        queue.async(execute: cancel)
    }

    func fetchDevices() -> AnyPublisher<[String], Never> {
        $servers.compactMap { $0.compactMap { $0.name } }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private func startBrowser() {
        guard !isStarted else { return }
        isStarted = true
        let browser = NWBrowser(for: .bonjour(type: BonjourService.type, domain: "local"), using: .tcp)
        browser.stateUpdateHandler = { [weak self] newState in
            guard let self = self, self.isEnabled else { return }
            if case .failed = newState { self.scheduleBrowserRetry() }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self, self.isEnabled else { return }
            self.servers = results
        }

        browser.start(queue: queue)

        self.browser = browser
    }

    private func scheduleBrowserRetry() {
        guard isStarted else { return }
        queue.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
            self?.startBrowser()
        }
    }

    private func cancel() {
        guard isStarted else { return }
        cancelBrowser()
        isStarted = false
    }

    private func cancelBrowser() {
        browser?.cancel()
        browser = nil
    }
}
