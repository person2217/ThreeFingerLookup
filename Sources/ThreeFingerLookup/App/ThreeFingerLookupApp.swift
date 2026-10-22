import SwiftUI
import AppKit

@main
struct ThreeFingerLookupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var runtime = LookupRuntime()

    var body: some Scene {
        MenuBarExtra("三指查词", systemImage: "hand.tap") {
            MenuView(runtime: runtime)
        }
        .menuBarExtraStyle(.menu)

        Window("设置", id: "settings") {
            SettingsView(runtime: runtime)
                .frame(width: 520, height: 560)
        }
        .defaultSize(width: 520, height: 560)
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var serviceProvider: LookupServiceProvider?
    private var terminationHandler: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func registerServices(_ provider: LookupServiceProvider, onTerminate: @escaping () -> Void) {
        serviceProvider = provider
        terminationHandler = onTerminate
        NSRegisterServicesProvider(provider, "ThreeFingerLookup")
    }

    func applicationWillTerminate(_ notification: Notification) {
        terminationHandler?()
        serviceProvider = nil
        terminationHandler = nil
    }
}
