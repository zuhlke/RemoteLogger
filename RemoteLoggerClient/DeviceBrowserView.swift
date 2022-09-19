import SwiftUI
import Combine
import BonjourServices
import Logging

struct DeviceBrowserView: View {
    @State private var devices: [String] = []

    let remoteLoggerClient: RemoteLoggerClient
    
    init(remoteLoggerClient: RemoteLoggerClient) {
        self.remoteLoggerClient = remoteLoggerClient
    }

    var body: some View {
        VStack {
            if devices.count > 0 {
                ForEach(devices, id: \.self) { device in
                    DeviceStateView(
                        remoteLoggerClient: remoteLoggerClient,
                        device: device
                    )
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView().id(UUID())
                    Spacer()
                }
            }
        }
        .onReceive(remoteLoggerClient.fetchDevices()) { devices in
            self.devices = devices
        }
    }
}
