import AppKit

final class LookupServiceProvider: NSObject {
    var onLookup: ((String) -> Void)?

    @objc func lookup(_ pasteboard: NSPasteboard) {
        guard let text = pasteboard.string(forType: .string) else { return }
        onLookup?(text)
    }
}
