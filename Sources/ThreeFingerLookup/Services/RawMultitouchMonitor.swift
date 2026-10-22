import Foundation
import os

final class RawMultitouchMonitor {
    private static let logger = Logger(subsystem: "com.reasonix.threefingerlookup", category: "touch")
    typealias Device = UnsafeMutableRawPointer
    typealias ContactCallback = @convention(c) (Device?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Void
    typealias CreateDevice = @convention(c) () -> Device?
    typealias RegisterCallback = @convention(c) (Device, ContactCallback) -> Void
    typealias StartDevice = @convention(c) (Device, Int32) -> Int32
    typealias StopDevice = @convention(c) (Device) -> Void

    private static let callback: ContactCallback = { _, _, count, timestamp, _ in
        RawMultitouchMonitor.dispatch(count: count, timestamp: timestamp)
    }
    private static let lock = NSLock()
    private static weak var activeMonitor: RawMultitouchMonitor?

    private var framework: UnsafeMutableRawPointer?
    private var device: Device?
    private var createDevice: CreateDevice?
    private var registerCallback: RegisterCallback?
    private var startDevice: StartDevice?
    private var stopDevice: StopDevice?

    var onTap: (() -> Void)?
    var onDiagnostic: ((String) -> Void)?
    private(set) var isRunning = false
    private(set) var isAvailable = false

    private var sawThreeFingerContact = false
    private var firstThreeFingerTimestamp: Double?
    private var lastFrameTimestamp: Double = 0
    private var lastContactCount = 0
    private var maximumContactCount = 0
    private var frameCount = 0
    private var recognizedTapCount = 0
    private let processingQueue = DispatchQueue(
        label: "com.reasonix.threefingerlookup.touch-processing",
        qos: .userInteractive
    )
    private let stateLock = NSLock()
    private var acceptingFrames = false
    private var settleWorkItem: DispatchWorkItem?
    private var lastDiagnosticTime: TimeInterval = 0

    func start() -> Bool {
        guard !isRunning else { return true }
        guard loadSymbols(),
              let createDevice,
              let registerCallback,
              let startDevice,
              let device = createDevice() else {
            isAvailable = false
            return false
        }

        self.device = device
        self.registerCallback = registerCallback
        self.startDevice = startDevice
        RawMultitouchMonitor.lock.lock()
        RawMultitouchMonitor.activeMonitor = self
        RawMultitouchMonitor.lock.unlock()
        stateLock.lock()
        acceptingFrames = true
        frameCount = 0
        maximumContactCount = 0
        recognizedTapCount = 0
        lastContactCount = 0
        lastFrameTimestamp = 0
        sawThreeFingerContact = false
        firstThreeFingerTimestamp = nil
        settleWorkItem = nil
        lastDiagnosticTime = 0
        stateLock.unlock()

        registerCallback(device, RawMultitouchMonitor.callback)
        let startResult = startDevice(device, 0)
        guard startResult == 0 else {
            RawMultitouchMonitor.lock.lock()
            RawMultitouchMonitor.activeMonitor = nil
            RawMultitouchMonitor.lock.unlock()
            stateLock.lock()
            acceptingFrames = false
            stateLock.unlock()
            self.device = nil
            isAvailable = false
            Self.logger.error("MTDeviceStart failed result=\(startResult, privacy: .public)")
            return false
        }
        isRunning = true
        isAvailable = true
        publishDiagnostic(force: true)
        Self.logger.info("raw multitouch monitor started")
        return true
    }

    func stop() {
        guard isRunning else { return }
        stateLock.lock()
        acceptingFrames = false
        settleWorkItem?.cancel()
        settleWorkItem = nil
        sawThreeFingerContact = false
        firstThreeFingerTimestamp = nil
        stateLock.unlock()
        if let device, let stopDevice {
            stopDevice(device)
        }
        RawMultitouchMonitor.lock.lock()
        if RawMultitouchMonitor.activeMonitor === self {
            RawMultitouchMonitor.activeMonitor = nil
        }
        RawMultitouchMonitor.lock.unlock()
        device = nil
        isRunning = false
    }

    deinit {
        stop()
        if let framework { dlclose(framework) }
    }

    private func loadSymbols() -> Bool {
        if createDevice != nil { return true }
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let framework = dlopen(path, RTLD_NOW | RTLD_LOCAL) else { return false }
        self.framework = framework
        guard let create: CreateDevice = symbol("MTDeviceCreateDefault"),
              let register: RegisterCallback = symbol("MTRegisterContactFrameCallback"),
              let start: StartDevice = symbol("MTDeviceStart"),
              let stop: StopDevice = symbol("MTDeviceStop") else {
            dlclose(framework)
            self.framework = nil
            return false
        }
        createDevice = create
        registerCallback = register
        startDevice = start
        stopDevice = stop
        return true
    }

    private func symbol<T>(_ name: String) -> T? {
        guard let framework, let pointer = dlsym(framework, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private static func dispatch(count: Int32, timestamp: Double) {
        lock.lock()
        let monitor = activeMonitor
        lock.unlock()
        guard let monitor else { return }
        monitor.process(count: Int(count), timestamp: timestamp)
    }

    private func process(count: Int, timestamp: Double) {
        var diagnostic: String?
        var pendingEnd: DispatchWorkItem?

        stateLock.lock()
        guard acceptingFrames else {
            stateLock.unlock()
            return
        }
        frameCount += 1
        lastContactCount = count
        maximumContactCount = max(maximumContactCount, count)
        lastFrameTimestamp = timestamp
        diagnostic = diagnosticMessageIfDue(force: false)

        if count >= 3 {
            if !sawThreeFingerContact {
                sawThreeFingerContact = true
                firstThreeFingerTimestamp = timestamp
            }
            settleWorkItem?.cancel()
            settleWorkItem = nil
        } else if sawThreeFingerContact {
            settleWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.finishGesture()
            }
            settleWorkItem = workItem
            pendingEnd = workItem
        }
        stateLock.unlock()

        if let diagnostic {
            let onDiagnostic = onDiagnostic
            DispatchQueue.main.async {
                onDiagnostic?(diagnostic)
            }
        }
        if let pendingEnd {
            processingQueue.asyncAfter(deadline: .now() + 0.14, execute: pendingEnd)
        }
    }

    private func finishGesture() {
        var recognized = false
        var gestureDuration: Double = 0
        var onTap: (() -> Void)?

        stateLock.lock()
        guard acceptingFrames, sawThreeFingerContact else {
            stateLock.unlock()
            return
        }
        gestureDuration = lastFrameTimestamp - (firstThreeFingerTimestamp ?? lastFrameTimestamp)
        sawThreeFingerContact = false
        firstThreeFingerTimestamp = nil
        settleWorkItem = nil
        if gestureDuration <= 0.55 {
            recognizedTapCount += 1
            recognized = true
            onTap = self.onTap
        }
        let diagnostic = diagnosticMessageIfDue(force: true)
        stateLock.unlock()

        if recognized {
            Self.logger.info("three finger tap recognized duration=\(gestureDuration, privacy: .public)")
        }
        if let diagnostic {
            let onDiagnostic = onDiagnostic
            DispatchQueue.main.async {
                onDiagnostic?(diagnostic)
            }
        }
        guard recognized else { return }
        DispatchQueue.main.async {
            onTap?()
        }
    }

    private func publishDiagnostic(force: Bool = false) {
        stateLock.lock()
        let message = diagnosticMessageIfDue(force: force)
        stateLock.unlock()
        guard let message else { return }
        let onDiagnostic = onDiagnostic
        DispatchQueue.main.async {
            onDiagnostic?(message)
        }
    }

    private func diagnosticMessageIfDue(force: Bool) -> String? {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastDiagnosticTime >= 0.25 else { return nil }
        lastDiagnosticTime = now
        if frameCount == 0 {
            return "监听已启动，尚未收到触控帧"
        }
        return "触控帧 \(frameCount) · 当前 \(lastContactCount) 指 · 峰值 \(maximumContactCount) 指 · 已识别 \(recognizedTapCount) 次"
    }
}
