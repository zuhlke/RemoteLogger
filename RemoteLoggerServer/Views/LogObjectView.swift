import SwiftUI
import BonjourServices

public struct LogObjectView: View {
    let object: LogOutput

    public init(
        object: LogOutput
    ) {
        self.object = object
    }

    public var body: some View {
        VStack {
            HStack {
                Text("\(String(object.timestamp.split(separator: "T").last!))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(object.label)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding([.top, .bottom], 2)
                    .padding([.leading, .trailing], 4)
                    .background(Color.purple.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(
                                Color.purple.opacity(0.5),
                                lineWidth: 1
                            )
                    )
                Text("\(object.level.rawValue)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding([.top, .bottom], 2)
                    .padding([.leading, .trailing], 4)
                    .background(color(object.level).opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(
                                color(object.level).opacity(0.5),
                                lineWidth: 1
                            )
                    )
            }
            HStack {
                Text(object.message)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
#if os(iOS)
                UIPasteboard.general.string = object.string()
#endif
            } label: { Text("Copy") }
        }
    }

    func color(_ level: LogOutput.Level) -> Color {
        switch level {
        case .trace: return .green
        case .info: return .blue
        case .debug: return .blue
        case .notice: return .yellow
        case .warning: return .yellow
        case .error: return .red
        case .critical: return .red
        }
    }
}
