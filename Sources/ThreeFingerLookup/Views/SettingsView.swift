import SwiftUI

struct SettingsView: View {
    @ObservedObject var runtime: LookupRuntime
    @ObservedObject private var monitor: ThreeFingerTapMonitor
    @Environment(\.scenePhase) private var scenePhase

    init(runtime: LookupRuntime) {
        self.runtime = runtime
        _monitor = ObservedObject(wrappedValue: runtime.monitor)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { runtime.settings.isEnabled }, set: { $0 ? runtime.enable() : runtime.disable() })
    }

    private var dictionaryBinding: Binding<DictionaryTarget> {
        Binding(get: { runtime.settings.dictionary }, set: { runtime.settings.dictionary = $0 })
    }

    private var gestureCheckFrequencyBinding: Binding<GestureCheckFrequency> {
        Binding(
            get: { runtime.settings.gestureCheckFrequency },
            set: { runtime.settings.gestureCheckFrequency = $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("词典应用", selection: dictionaryBinding) {
                            ForEach(DictionaryTarget.allCases) { target in
                                Text(target.title).tag(target)
                            }
                        }
                        Text("查询地址：\(runtime.settings.dictionary.scheme)://…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } label: {
                    Label("查询目标", systemImage: "books.vertical")
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: runtime.accessibilityState == .granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(runtime.accessibilityState == .granted ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("辅助功能")
                                Text("读取指针位置和文字内容").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if runtime.accessibilityState == .granted {
                                Text("已允许").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Button("打开设置", action: runtime.openAccessibilitySettings)
                            }
                        }
                        Divider()
                        HStack {
                            Image(systemName: runtime.screenRecordingState == .granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(runtime.screenRecordingState == .granted ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("屏幕录制")
                                Text("OCR 需要截取指针附近的画面").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if runtime.screenRecordingState == .granted {
                                Text("已允许").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Button("打开设置", action: runtime.openScreenRecordingSettings)
                            }
                        }
                        Divider()
                        HStack {
                            Image(systemName: "hand.tap.fill").foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("系统三指轻点")
                                Text(runtime.settings.isEnabled ? "启用时自动关闭，退出或关闭后恢复" : "当前由系统设置决定")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(runtime.settings.isEnabled ? "由本应用接管" : "未接管")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Divider()
                        Picker("系统手势巡检", selection: gestureCheckFrequencyBinding) {
                            ForEach(GestureCheckFrequency.allCases) { frequency in
                                Text("\(frequency.title)（\(frequency.intervalTitle)）").tag(frequency)
                            }
                        }
                        Text("应用运行期间，按此间隔检查并关闭被重新打开的系统三指轻点。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } label: {
                    Label("权限与冲突", systemImage: "lock.shield")
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("启用 OCR 识别不可选文字", isOn: Binding(
                            get: { runtime.settings.ocrFallbackEnabled },
                            set: { runtime.setOCRFallbackEnabled($0) }
                        ))
                        .toggleStyle(.checkbox)
                        Text("可选文本优先由辅助功能定位；无法读取时，OCR 可识别图片等不可选文字。")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("测试 OCR", action: runtime.testOCR)
                            .buttonStyle(.bordered)
                    }
                } label: {
                    Label("取词方式", systemImage: "text.viewfinder")
                }
                GroupBox {
                    HStack {
                        Text(runtime.lookupStatus.message)
                        Spacer()
                        Text(monitor.isRunning ? "监听中 · \(monitor.backendName)" : "未监听")
                            .foregroundStyle(.secondary)
                    }
                    if monitor.isRunning {
                        Text(monitor.diagnosticSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } label: {
                    Label("状态", systemImage: "waveform.path.ecg")
                }
            }
            .padding(24)
        }
        .frame(minWidth: 480, minHeight: 500)
        .onAppear {
            runtime.refreshAccessibilityState()
            runtime.refreshScreenRecordingState()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            runtime.refreshAccessibilityState()
            runtime.refreshScreenRecordingState()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("三指查词").font(.title2.weight(.semibold))
                Text("把指针下的文字发送给你常用的词典").foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: enabledBinding).toggleStyle(.switch).labelsHidden()
        }
    }
}
