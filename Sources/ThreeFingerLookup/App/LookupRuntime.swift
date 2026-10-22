import AppKit
import Combine

@MainActor
final class LookupRuntime: ObservableObject {
    let settings: SettingsStore
    let gestureSettings = SystemGestureSettingsManager()
    let dictionaryLauncher = DictionaryLauncher()
    let textProvider = TextUnderPointerProvider()
    let ocrRecognizer = ScreenTextRecognizer()
    let monitor = ThreeFingerTapMonitor()
    let serviceProvider = LookupServiceProvider()

    @Published var lookupStatus = LookupStatus()
    @Published private(set) var accessibilityState: PermissionState = .unknown
    @Published private(set) var screenRecordingState: PermissionState = .unknown
    private var settingsCancellable: AnyCancellable?
    private var frequencyCancellable: AnyCancellable?
    private var gestureEnforcementTimer: Timer?

    init() {
        settings = SettingsStore()
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        frequencyCancellable = settings.$gestureCheckFrequency.dropFirst().sink { [weak self] _ in
            self?.startGestureEnforcement()
        }
        monitor.onTap = { [weak self] in self?.performPointerLookup() }
        serviceProvider.onLookup = { [weak self] text in self?.lookup(text) }
        refreshAccessibilityState()
        refreshScreenRecordingState()
        if settings.isEnabled { enable() }
        DispatchQueue.main.async { [weak self] in
            guard let self, let delegate = NSApp.delegate as? AppDelegate else { return }
            delegate.registerServices(self.serviceProvider) {
                self.stop()
            }
        }
    }

    func enable() {
        settings.isEnabled = true
        gestureSettings.prepareForPlugin()
        startGestureEnforcement()
        monitor.start()
        lookupStatus = LookupStatus(message: "已启用三指查词")
    }

    func disable() {
        settings.isEnabled = false
        gestureEnforcementTimer?.invalidate()
        gestureEnforcementTimer = nil
        monitor.stop()
        gestureSettings.restoreIfOwned()
        lookupStatus = LookupStatus(message: "功能已关闭")
    }

    func toggle() {
        settings.isEnabled ? disable() : enable()
    }

    func lookup(_ rawText: String) {
        let word = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).first ?? rawText
        guard dictionaryLauncher.open(word: word, target: settings.dictionary) else {
            lookupStatus = LookupStatus(message: "未能打开\(settings.dictionary.title)", isError: true)
            return
        }
        lookupStatus = LookupStatus(message: "已发送“\(word)”到\(settings.dictionary.title)")
    }

    func performPointerLookup() {
        guard settings.isEnabled else { return }
        if let word = textProvider.wordUnderPointer() {
            lookup(word)
            return
        }

        guard settings.ocrFallbackEnabled else {
            lookupStatus = LookupStatus(message: "没有读取到可选文字；图片文字可启用 OCR", isError: true)
            return
        }

        lookupStatus = LookupStatus(message: "正在识别指针下的文字…")
        ocrRecognizer.recognizeWordUnderPointer { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let word): self.lookup(word)
            case .failure(let error):
                self.lookupStatus = LookupStatus(message: error.localizedDescription, isError: true)
            }
        }
    }

    func setOCRFallbackEnabled(_ enabled: Bool) {
        settings.ocrFallbackEnabled = enabled
        if enabled {
            refreshScreenRecordingState()
            if screenRecordingState != .granted {
                _ = ocrRecognizer.requestScreenRecordingPermission()
                refreshScreenRecordingState()
            }
        }
    }

    func testOCR() {
        refreshScreenRecordingState()
        guard screenRecordingState == .granted else {
            lookupStatus = LookupStatus(message: "请先允许屏幕录制权限", isError: true)
            openScreenRecordingSettings()
            return
        }
        lookupStatus = LookupStatus(message: "正在测试 OCR…")
        ocrRecognizer.recognizeWordUnderPointer { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let text):
                self.lookupStatus = LookupStatus(message: "OCR 识别结果：\(text)")
            case .failure(let error):
                self.lookupStatus = LookupStatus(message: "OCR 测试失败：\(error.localizedDescription)", isError: true)
            }
        }
    }

    func refreshAccessibilityState() {
        accessibilityState = AXIsProcessTrusted() ? .granted : .missing
    }

    func refreshScreenRecordingState() {
        screenRecordingState = ocrRecognizer.hasScreenRecordingPermission() ? .granted : .missing
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    func installed(_ target: DictionaryTarget) -> Bool {
        dictionaryLauncher.isInstalled(target)
    }

    func stop() {
        gestureEnforcementTimer?.invalidate()
        gestureEnforcementTimer = nil
        monitor.stop()
        gestureSettings.restoreIfOwned()
    }

    private func startGestureEnforcement() {
        guard settings.isEnabled else { return }
        gestureEnforcementTimer?.invalidate()
        let frequency = settings.gestureCheckFrequency
        gestureEnforcementTimer = Timer.scheduledTimer(withTimeInterval: frequency.interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.gestureSettings.enforceDisabledIfOwned()
            }
        }
        gestureEnforcementTimer?.tolerance = min(frequency.interval * 0.15, 5)
    }
}
