import AppKit
import ApplicationServices
import LookupText

final class TextUnderPointerProvider {
    func wordUnderPointer() -> String? {
        guard let location = CGEvent(source: nil)?.location else { return nil }
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(location.x), Float(location.y), &element) == .success,
              let element else { return nil }

        var rangeValue: CFTypeRef?
        var pointStruct = CGPoint(x: location.x, y: location.y)
        guard let point = AXValueCreate(.cgPoint, &pointStruct),
              AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXRangeForPositionParameterizedAttribute as CFString,
                point,
                &rangeValue
              ) == .success,
              let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }

        let axRange = rangeValue as! AXValue
        var characterRange = CFRange(location: kCFNotFound, length: 0)
        guard AXValueGetType(axRange) == .cfRange,
              AXValueGetValue(axRange, .cfRange, &characterRange),
              characterRange.location != kCFNotFound,
              characterRange.length > 0 else { return nil }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              let text = value as? String, !text.isEmpty else { return nil }
        guard characterRange.location >= 0,
              characterRange.location < (text as NSString).length,
              let termRange = WordAtPointer.tokenRange(in: text, utf16Offset: characterRange.location) else { return nil }

        var range = CFRange(location: termRange.location, length: termRange.length)
        guard let rangeValue = AXValueCreate(.cfRange, &range) else { return nil }
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        ) == .success,
        let boundsValue,
        CFGetTypeID(boundsValue) == AXValueGetTypeID() else { return nil }

        let axBounds = boundsValue as! AXValue
        var termBounds = CGRect.zero
        guard AXValueGetType(axBounds) == .cgRect,
              AXValueGetValue(axBounds, .cgRect, &termBounds),
              termBounds.width > 0,
              termBounds.height > 0,
              termBounds.insetBy(dx: -2, dy: -2).contains(location) else { return nil }

        return (text as NSString).substring(with: termRange)
    }
}
