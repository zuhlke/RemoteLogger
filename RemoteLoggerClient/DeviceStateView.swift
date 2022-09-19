import SwiftUI
import Combine
import BonjourServices
import Logging

struct DeviceStateView: View {
    @State private var state: RemoteLogsConnectionState = .idle

    let remoteLoggerClient: RemoteLoggerClient
    let device: String

    init(
        remoteLoggerClient: RemoteLoggerClient,
        device: String
    ) {
        self.remoteLoggerClient = remoteLoggerClient
        self.device = device
    }

    var body: some View {
        VStack {
            Button {
                if state != .idle {
                    remoteLoggerClient.disconnect()
                } else {
                    remoteLoggerClient.connect(to: device)
                }
            } label: {
                HStack {
                    Text(device)
                    Spacer()
                    if state == .connecting {
                        ProgressView().padding(2)
                    } else if state == .connected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .onReceive(remoteLoggerClient.isConnected(to: device)) { state in
            self.state = state
        }
    }
}
