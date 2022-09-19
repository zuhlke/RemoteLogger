import SwiftUI
import Logging
import BonjourServices

@main
struct RemoteLoggerClientApp: App {
    init() {
        LoggingSystem.bootstrap { label in
            var streamHandler = StreamLogHandler.standardOutput(label: label)
            streamHandler.logLevel = .trace
            
            var remoteHandler = RemoteLogOutputStream.logger(label: label, remoteLoggerClient: RemoteLoggerClient.shared)
            remoteHandler.logLevel = .trace
    
            return MultiplexLogHandler([streamHandler, remoteHandler])
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(remoteLoggerClient: RemoteLoggerClient.shared)
        }
    }
}
