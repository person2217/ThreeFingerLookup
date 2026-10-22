import XCTest
import LookupText

final class WordAtPointerTests: XCTestCase {
    func testSelectsChineseWordAtCharacterPositionInsteadOfWholeSentence() {
        let text = "我刚刚在软件里看到苹果手机，但是没查成功。"
        let offset = (text as NSString).range(of: "软件").location + 1

        XCTAssertEqual(WordAtPointer.resolve(in: text, utf16Offset: offset), "软件")
    }

    func testSelectsEnglishWordAtCharacterPosition() {
        let text = "Look up the highlighted word"
        let offset = (text as NSString).range(of: "highlighted").location + 4

        XCTAssertEqual(WordAtPointer.resolve(in: text, utf16Offset: offset), "highlighted")
    }

    func testDoesNotSelectAnUnrelatedWordWhenPointerIsOnPunctuation() {
        XCTAssertNil(WordAtPointer.resolve(in: "前文，目标词", utf16Offset: 2))
    }

    func testOCRUsesRecognizedWordBoundsInsteadOfUniformCharacterWidths() {
        let text = "我刚刚在软件里看到苹果手机，但是没查成功。"
        let ranges = WordAtPointer.tokenRanges(in: text)
        let softwareRange = (text as NSString).range(of: "软件")
        let softwareIndex = ranges.firstIndex(of: softwareRange)
        XCTAssertNotNil(softwareIndex)

        let bounds: [CGRect?] = ranges.indices.map { index in
            index == softwareIndex
                ? CGRect(x: 0.42, y: 0.4, width: 0.16, height: 0.2)
                : CGRect(x: 0.02, y: 0.8, width: 0.04, height: 0.08)
        }

        XCTAssertEqual(
            WordAtPointer.resolve(in: text, tokenBounds: bounds, point: CGPoint(x: 0.5, y: 0.5)),
            "软件"
        )
    }

    func testOCRCharacterProportionsLocateTheWordInsideARecognizedLine() {
        let text = "我刚刚在软件里看到苹果手机，但是没查成功。"
        let lineBounds = CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2)
        let ranges = WordAtPointer.tokenRanges(in: text)
        let softwareRange = (text as NSString).range(of: "软件")
        let softwareIndex = ranges.firstIndex(of: softwareRange)
        XCTAssertNotNil(softwareIndex)
        let bounds = WordAtPointer.proportionalTokenBounds(in: text, lineBounds: lineBounds)
        let softwareBounds = bounds[softwareIndex!]
        XCTAssertNotNil(softwareBounds)

        XCTAssertEqual(
            WordAtPointer.resolve(in: text, tokenBounds: bounds, point: CGPoint(x: softwareBounds!.midX, y: softwareBounds!.midY)),
            "软件"
        )
    }

    func testOCRDoesNotChooseNearestTokenWhenPointerIsOnWhitespace() {
        let text = "alpha beta"
        let bounds = WordAtPointer.proportionalTokenBounds(
            in: text,
            lineBounds: CGRect(x: 0, y: 0.4, width: 1, height: 0.2)
        )

        XCTAssertNil(WordAtPointer.resolve(in: text, tokenBounds: bounds, point: CGPoint(x: 0.55, y: 0.5)))
    }

    func testScreenPointMapsToVisionBottomLeftCoordinates() {
        let screenRect = CGRect(x: 100, y: 200, width: 200, height: 100)

        XCTAssertEqual(
            WordAtPointer.visionNormalizedPoint(fromScreenPoint: CGPoint(x: 100, y: 200), inTopLeftRect: screenRect),
            CGPoint(x: 0, y: 1)
        )
        XCTAssertEqual(
            WordAtPointer.visionNormalizedPoint(fromScreenPoint: CGPoint(x: 200, y: 250), inTopLeftRect: screenRect),
            CGPoint(x: 0.5, y: 0.5)
        )
    }

    func testInvalidPositionDoesNotFallBackToFullSentence() {
        XCTAssertNil(WordAtPointer.resolve(in: "这是一整句话", utf16Offset: 100))
    }

    func testSelectsRussianWordAtCharacterPosition() {
        let text = "Привет, как дела?"
        let offset = (text as NSString).range(of: "Привет").location + 2

        XCTAssertEqual(WordAtPointer.resolve(in: text, utf16Offset: offset), "Привет")
    }

    func testGoldenDictChineseWordUsesURLPathAndPopupTarget() {
        let url = GoldenDictURL.make(for: "中文")

        XCTAssertEqual(url?.absoluteString, "goldendict:///%E4%B8%AD%E6%96%87?target=popup")
        XCTAssertTrue(url?.host == nil || url?.host?.isEmpty == true)
        XCTAssertEqual(url?.path, "/中文")
        XCTAssertEqual(url?.query, "target=popup")
        XCTAssertFalse(url?.absoluteString.contains("xn--") ?? true)
    }

    func testGoldenDictRussianWordUsesURLPathWithoutIDNHost() {
        let url = GoldenDictURL.make(for: "Привет")

        XCTAssertEqual(url?.absoluteString, "goldendict:///%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82?target=popup")
        XCTAssertTrue(url?.host == nil || url?.host?.isEmpty == true)
        XCTAssertEqual(url?.path, "/Привет")
        XCTAssertEqual(url?.query, "target=popup")
        XCTAssertFalse(url?.absoluteString.contains("xn--") ?? true)
    }

    func testGoldenDictReservedCharactersStayInThePath() {
        let url = GoldenDictURL.make(for: "C++/C#")

        XCTAssertEqual(url?.path, "/C++/C#")
        XCTAssertTrue(url?.host == nil || url?.host?.isEmpty == true)
        XCTAssertEqual(url?.query, "target=popup")
    }

    func testGoldenDictRejectsAnEmptyWord() {
        XCTAssertNil(GoldenDictURL.make(for: " \n "))
    }
}
