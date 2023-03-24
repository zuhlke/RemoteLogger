import SwiftUI
import BonjourServices

public struct LogsView: View {
    let logOutputs: [LogOutput]

    public init(
        logOutputs: [LogOutput]
    ) {
        self.logOutputs = logOutputs
    }

    public var body: some View {
        List {
            ForEach(logOutputs, id: \.id) { object in
                if object.metadata == "" {
                    LogObjectView(object: object)
                } else {
                    NavigationLink(
                        destination: List {
                            Text(object.metadata).lineLimit(nil)
                        }.listStyle(PlainListStyle())
                    ) {
                        LogObjectView(object: object)
                    }
                }
            }
        }
    }
}
