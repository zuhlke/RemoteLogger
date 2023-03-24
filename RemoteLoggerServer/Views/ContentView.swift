import SwiftUI
import BonjourServices

struct ContentView: View {
    @ObservedObject var server = RemoteLoggerServer.shared
    
    init() {
        server.startListening()
    }

    var body: some View {
        NavigationView {
            LogsView(logOutputs: server.logs.map {
                LogOutput(
                    timestamp: $0.timestamp,
                    level: LogOutput.Level.init(rawValue: $0.level)!,
                    label: $0.label,
                    source: $0.source,
                    message: $0.message,
                    metadata: $0.metadata
                )
            })
        }
    }
}
