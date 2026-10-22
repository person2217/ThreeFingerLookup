import AppKit
import Combine

@MainActor
final class ThreeFingerTapMonitor: ObservableObject {
    var onTap: (() -> Void)?
    private let rawMonitor = RawMultitouchMonitor()
    private var monitor: Any?
    private var lastTap = Date.distantPast
    private var sawThreeFingerGesture = false
    @Published private(set) var diagnosticSummary = "尚未启动触控监听"
    private(set) var isRunning = false
    private(set) var backendName = "未监听"

    func start() {
        guard monitor == nil else { return }
        rawMonitor.onTap = { [weak self] in
            guard let self, Date().timeIntervalSince(self.lastTap) > 0.6 else { return }
            self.lastTap = Date()
            self.onTap?()
        }
        rawMonitor.onDiagnostic = { [weak self] message in self?.diagnosticSummary = message }
        if rawMonitor.start() {
            isRunning = true
            backendName = "原始触控"
            return
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .gesture) { [weak self] event in
            guard let self else { return }
            let touches = event.allTouches()
            if touches.count >= 3 {
                self.sawThreeFingerGesture = true
            }
            guard self.sawThreeFingerGesture, event.phase == .ended else { return }
            self.sawThreeFingerGesture = false
            guard Date().timeIntervalSince(self.lastTap) > 0.6 else { return }
            self.lastTap = Date()
            self.onTap?()
        }
        isRunning = monitor != nil
        backendName = isRunning ? "AppKit gesture" : "不可用"
        diagnosticSummary = isRunning ? "AppKit 手势监听已启动" : "无法启动触控监听"
    }

    func stop() {
        rawMonitor.stop()
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        sawThreeFingerGesture = false
        isRunning = false
        backendName = "未监听"
        diagnosticSummary = "监听已停止"
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
