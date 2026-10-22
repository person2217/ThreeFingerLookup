import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }
    @Published var dictionary: DictionaryTarget {
        didSet { defaults.set(dictionary.rawValue, forKey: Keys.dictionary) }
    }
    @Published var ocrFallbackEnabled: Bool {
        didSet { defaults.set(ocrFallbackEnabled, forKey: Keys.ocrFallback) }
    }
    @Published var gestureCheckFrequency: GestureCheckFrequency {
        didSet { defaults.set(gestureCheckFrequency.rawValue, forKey: Keys.gestureCheckFrequency) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let dictionary = "dictionary"
        static let ocrFallback = "ocrFallbackEnabled"
        static let gestureCheckFrequency = "gestureCheckFrequency"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? false
        let raw = defaults.string(forKey: Keys.dictionary) ?? DictionaryTarget.eudic.rawValue
        self.dictionary = DictionaryTarget(rawValue: raw) ?? .eudic
        self.ocrFallbackEnabled = defaults.object(forKey: Keys.ocrFallback) as? Bool ?? false
        let frequency = defaults.string(forKey: Keys.gestureCheckFrequency) ?? GestureCheckFrequency.normal.rawValue
        self.gestureCheckFrequency = GestureCheckFrequency(rawValue: frequency) ?? .normal
    }
}
