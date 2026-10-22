import Foundation
import CoreGraphics
import CoreServices
import NaturalLanguage

public enum WordAtPointer {
    private struct Token {
        let range: NSRange
        let value: String
    }

    public static func resolve(in text: String, utf16Offset: Int) -> String? {
        guard let range = tokenRange(in: text, utf16Offset: utf16Offset) else { return nil }
        return (text as NSString).substring(with: range)
    }

    public static func tokenRange(in text: String, utf16Offset: Int) -> NSRange? {
        let source = text as NSString
        guard source.length > 0, utf16Offset >= 0, utf16Offset < source.length else { return nil }

        let dictionaryRange = DCSGetTermRangeInString(nil, text as CFString, utf16Offset)
        if dictionaryRange.location != kCFNotFound,
           dictionaryRange.length > 0,
           dictionaryRange.location >= 0,
           dictionaryRange.location + dictionaryRange.length <= source.length,
           NSLocationInRange(utf16Offset, NSRange(location: dictionaryRange.location, length: dictionaryRange.length)) {
            return NSRange(location: dictionaryRange.location, length: dictionaryRange.length)
        }

        return lexicalTokens(in: text).first(where: { NSLocationInRange(utf16Offset, $0.range) })?.range
    }

    public static func tokenRanges(in text: String) -> [NSRange] {
        lexicalTokens(in: text).map(\.range)
    }

    public static func proportionalTokenBounds(in text: String, lineBounds: CGRect) -> [CGRect?] {
        let tokens = lexicalTokens(in: text)
        let characters = text.count
        guard characters > 0,
              lineBounds.width > 0,
              lineBounds.height > 0,
              lineBounds.minX.isFinite,
              lineBounds.minY.isFinite,
              lineBounds.width.isFinite,
              lineBounds.height.isFinite else {
            return Array(repeating: nil, count: tokens.count)
        }

        return tokens.map { token in
            guard let range = Range(token.range, in: text) else { return nil }
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.distance(from: text.startIndex, to: range.upperBound)
            let startRatio = CGFloat(start) / CGFloat(characters)
            let endRatio = CGFloat(end) / CGFloat(characters)
            return CGRect(
                x: lineBounds.minX + lineBounds.width * startRatio,
                y: lineBounds.minY,
                width: lineBounds.width * (endRatio - startRatio),
                height: lineBounds.height
            )
        }
    }

    public static func visionNormalizedPoint(fromScreenPoint point: CGPoint, inTopLeftRect rect: CGRect) -> CGPoint? {
        guard rect.width > 0,
              rect.height > 0,
              rect.minX.isFinite,
              rect.minY.isFinite,
              rect.width.isFinite,
              rect.height.isFinite,
              point.x >= rect.minX,
              point.x <= rect.maxX,
              point.y >= rect.minY,
              point.y <= rect.maxY else { return nil }

        return CGPoint(
            x: (point.x - rect.minX) / rect.width,
            y: 1 - (point.y - rect.minY) / rect.height
        )
    }

    public static func resolve(in text: String, tokenBounds: [CGRect?], point: CGPoint) -> String? {
        let tokens = lexicalTokens(in: text)
        guard tokens.count == tokenBounds.count, point.x.isFinite, point.y.isFinite else { return nil }

        let candidates = zip(tokens, tokenBounds).compactMap { token, bounds -> (Token, CGRect, CGFloat)? in
            guard let bounds,
                  bounds.size.width > 0,
                  bounds.size.height > 0,
                  bounds.minX.isFinite,
                  bounds.minY.isFinite,
                  bounds.maxX.isFinite,
                  bounds.maxY.isFinite else { return nil }
            guard bounds.insetBy(dx: -0.003, dy: -0.01).contains(point) else { return nil }
            let dx = bounds.midX - point.x
            let dy = bounds.midY - point.y
            return (token, bounds, hypot(dx, dy))
        }
        guard let match = candidates.min(by: { $0.2 < $1.2 }),
              let range = Range(match.0.range, in: text) else { return nil }

        let characterCount = text.distance(from: range.lowerBound, to: range.upperBound)
        guard characterCount > 0 else { return nil }
        let fraction = min(max((point.x - match.1.minX) / match.1.width, 0), 0.999999)
        let characterOffset = min(Int(fraction * CGFloat(characterCount)), characterCount - 1)
        let characterIndex = text.index(range.lowerBound, offsetBy: characterOffset)
        let utf16Offset = text.utf16.distance(from: text.utf16.startIndex, to: characterIndex)
        return resolve(in: text, utf16Offset: utf16Offset)
    }

    private static func lexicalTokens(in text: String) -> [Token] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(language(for: text))

        var tokens: [Token] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let utf16Range = NSRange(range, in: text)
            let value = (text as NSString).substring(with: utf16Range)
            guard value.rangeOfCharacter(from: .alphanumerics) != nil else { return true }
            tokens.append(Token(range: utf16Range, value: value))
            return true
        }
        return tokens
    }

    private static func language(for text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        switch recognizer.dominantLanguage?.rawValue {
        case "zh-Hant": return .traditionalChinese
        case "zh-Hans", "zh": return .simplifiedChinese
        case "ja": return .japanese
        case "ko": return .korean
        case "ru": return .russian
        default: return .english
        }
    }
}
