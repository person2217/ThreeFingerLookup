import Foundation

public enum GoldenDictURL {
    public static func make(for word: String) -> URL? {
        let cleaned = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "goldendict"
        components.host = ""
        components.path = "/" + cleaned
        components.queryItems = [URLQueryItem(name: "target", value: "popup")]
        return components.url
    }
}
