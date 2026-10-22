import SwiftUI

struct MenuView: View {
    @ObservedObject var runtime: LookupRuntime
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("三指查词").font(.headline)
            HStack(spacing: 8) {
                Circle().fill(runtime.settings.isEnabled ? .green : .secondary).frame(width: 8, height: 8)
                Text(runtime.settings.isEnabled ? "正在监听三指轻点" : "功能已关闭")
                    .foregroundStyle(.secondary)
            }
            Divider()
            Button(runtime.settings.isEnabled ? "关闭三指查词" : "启用三指查词") {
                runtime.toggle()
            }
            Button("打开设置") { openWindow(id: "settings") }
            Divider()
            Text(runtime.lookupStatus.message)
                .font(.caption)
                .foregroundStyle(runtime.lookupStatus.isError ? .red : .secondary)
                .lineLimit(2)
            Divider()
            Button("退出") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 260)
    }
}
