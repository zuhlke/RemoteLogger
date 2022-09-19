import SwiftUI
import BonjourServices

struct ContentView: View {
    @ObservedObject var server = RemoteLoggerServer.shared
    
    init() {
        server.startListening()
    }

    var body: some View {
        List(server.logs) { logInfo in
            Text(logInfo.string())
        }
    }
}
