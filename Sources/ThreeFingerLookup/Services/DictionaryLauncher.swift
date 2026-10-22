import AppKit
import LookupText

final class DictionaryLauncher {
    func isInstalled(_ target: DictionaryTarget) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleIdentifier) != nil
    }

    @discardableResult
    func open(word: String, target: DictionaryTarget) -> Bool {
        let cleaned = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        switch target {
        case .eudic:
            let pathCharacters = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
            guard let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: pathCharacters) else { return false }
            guard let url = URL(string: "eudic://dict/\(encoded)") else { return false }
            return NSWorkspace.shared.open(url)
        case .goldenDict:
            guard
                isInstalled(.goldenDict),
                let url = GoldenDictURL.make(for: cleaned)
            else {
                return false
            }

            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.open(url, configuration: configuration) { _, _ in }
            return true
        }
    }
}
