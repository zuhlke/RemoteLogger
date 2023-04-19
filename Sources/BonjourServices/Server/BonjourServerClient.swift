// Portions of this file are modified from Pulse Pro
// (https://github.com/kean/PulsePro) by Alexander Grebenyuk.

import SwiftUI
import Combine
import Network
import CommonCrypto

struct BonjourServerClientId: Hashable, Codable {
    let raw: String

    init(request: PacketClientHello) {
        self.raw = request.deviceId.uuidString + (request.appInfo.bundleIdentifier ?? "–")
    }

    init(_ id: String) {
        self.raw = id
    }
}

final class BonjourServerClient: ObservableObject, Identifiable {
    var id: BonjourServerClientId { info.id }
    var deviceId: UUID { info.deviceId }
    var deviceInfo: DeviceInfo { info.deviceInfo }
    var appInfo: AppInfo { info.appInfo }

    let info: BonjourServerClientInfo

    var connection: BonjourConnection?

    @Published private(set) var isConnected = false
    @Published private(set) var isPaused = true

    private var pingTimer: Timer?
    private var timeoutDisconnectItem: DispatchWorkItem?

    private var didFailToUpdateStatus = false

    deinit {
        pingTimer?.invalidate()
    }

    init(info: BonjourServerClientInfo) throws {
        self.info = info
        pingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.connection?.send(code: .ping)
        }
    }

    func didConnectExistingClient() {
        isConnected = true
        sendConnectionStatus()
    }

    func didReceivePing() {
        if !isConnected {
            isConnected = true
        }
        scheduleAutomaticDisconnect()

        if didFailToUpdateStatus {
            didFailToUpdateStatus = false
            connection?.send(code: isPaused ? .pause : .resume)
        }
    }

    func pause() {
        isPaused = true
        sendConnectionStatus()
    }

    func resume() {
        isPaused = false
        sendConnectionStatus()
    }

    func togglePlay() {
        isPaused ? resume() : pause()
    }

    private func sendConnectionStatus() {
        didFailToUpdateStatus = false
        let isPaused = self.isPaused
        connection?.send(code: isPaused ? .pause : .resume) { [weak self] error in
            if error != nil {
                self?.didFailToUpdateStatus = true
            }
        }
    }

    private func scheduleAutomaticDisconnect() {
        timeoutDisconnectItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isConnected = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(6), execute: item)
        timeoutDisconnectItem = item
    }
}

final class BonjourServerClientInfo: Codable {
    let id: BonjourServerClientId
    var deviceId: UUID
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo

    init(info: PacketClientHello) {
        self.id = BonjourServerClientId(request: info)
        self.deviceId = info.deviceId
        self.deviceInfo = info.deviceInfo
        self.appInfo = info.appInfo
    }
}

extension Data {
    /// Calculates SHA256 from the given string and returns its hex representation.
    ///
    /// ```swift
    /// print("http://test.com".data(using: .utf8)!.sha256)
    /// // prints "8b408a0c7163fdfff06ced3e80d7d2b3acd9db900905c4783c28295b8c996165"
    /// ```
    fileprivate var sha256: String {
        let hash = withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.baseAddress, CC_LONG(count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
