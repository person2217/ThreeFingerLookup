import AppKit
import ScreenCaptureKit
import Vision
import LookupText

final class ScreenTextRecognizer {
    enum RecognitionError: LocalizedError {
        case permissionDenied
        case captureFailed
        case noText

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "需要屏幕录制权限"
            case .captureFailed: return "无法截取指针附近的画面"
            case .noText: return "OCR 没有识别到文字"
            }
        }
    }

    func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func recognizeWordUnderPointer(completion: @escaping (Result<String, Error>) -> Void) {
        guard hasScreenRecordingPermission() else {
            DispatchQueue.main.async { completion(.failure(RecognitionError.permissionDenied)) }
            return
        }

        guard let point = CGEvent(source: nil)?.location else {
            DispatchQueue.main.async { completion(.failure(RecognitionError.captureFailed)) }
            return
        }
        guard let displayBounds = activeDisplayBounds(containing: point) else {
            DispatchQueue.main.async { completion(.failure(RecognitionError.captureFailed)) }
            return
        }
        let captureRect = CGRect(x: point.x - 360, y: point.y - 180, width: 720, height: 360)
            .intersection(displayBounds)
        guard !captureRect.isNull,
              let pointer = WordAtPointer.visionNormalizedPoint(fromScreenPoint: point, inTopLeftRect: captureRect) else {
            DispatchQueue.main.async { completion(.failure(RecognitionError.captureFailed)) }
            return
        }
        captureImage(in: captureRect) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let image):
                self.recognize(image: image, pointer: pointer, completion: completion)
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func captureImage(in rect: CGRect, completion: @escaping (Result<CGImage, Error>) -> Void) {
        if #available(macOS 15.2, *) {
            SCScreenshotManager.captureImage(in: rect) { image, error in
                if let error {
                    completion(.failure(error))
                } else if let image {
                    completion(.success(image))
                } else {
                    completion(.failure(RecognitionError.captureFailed))
                }
            }
            return
        }

        guard let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            completion(.failure(RecognitionError.captureFailed))
            return
        }
        completion(.success(image))
    }

    private func recognize(image: CGImage, pointer: CGPoint, completion: @escaping (Result<String, Error>) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let imageWidth = CGFloat(image.width)
            let imageHeight = CGFloat(image.height)
            let ranked = observations.compactMap { observation -> (VNRecognizedText, CGRect, CGFloat, CGFloat)? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let box = observation.boundingBox
                let dx = max(box.minX - pointer.x, 0, pointer.x - box.maxX)
                let dy = max(box.minY - pointer.y, 0, pointer.y - box.maxY)
                let distance = hypot(dx * imageWidth, dy * imageHeight)
                let area = box.width * box.height
                return (candidate, box, distance, area)
            }.filter { $0.1.insetBy(dx: -0.015, dy: -0.02).contains(pointer) }
                .sorted { lhs, rhs in
                    if lhs.2 != rhs.2 { return lhs.2 < rhs.2 }
                    return lhs.3 < rhs.3
                }

            guard let match = ranked.first else {
                DispatchQueue.main.async { completion(.failure(RecognitionError.noText)) }
                return
            }

            let text = match.0.string
            let tokenBounds = self.tokenBounds(for: match.0, lineBounds: match.1)
            guard let word = WordAtPointer.resolve(in: text, tokenBounds: tokenBounds, point: pointer) else {
                DispatchQueue.main.async { completion(.failure(RecognitionError.noText)) }
                return
            }
            DispatchQueue.main.async { completion(.success(word)) }
        }
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let supportedLanguages = (try? request.supportedRecognitionLanguages()) ?? []
        request.recognitionLanguages = ["zh-Hans", "en-US", "ru-RU"].filter(supportedLanguages.contains)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func tokenBounds(for recognizedText: VNRecognizedText, lineBounds: CGRect) -> [CGRect?] {
        let text = recognizedText.string
        let ranges = WordAtPointer.tokenRanges(in: text)
        if text.unicodeScalars.contains(where: isIdeographic) {
            return WordAtPointer.proportionalTokenBounds(in: text, lineBounds: lineBounds)
        }

        return ranges.map { tokenRange in
            guard let range = Range(tokenRange, in: text),
                  let rectangle = try? recognizedText.boundingBox(for: range) else { return nil }
            return rectangle.boundingBox
        }
    }

    private func isIdeographic(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (0x2E80...0x9FFF).contains(value)
            || (0xF900...0xFAFF).contains(value)
            || (0x20000...0x3134F).contains(value)
    }

    private func activeDisplayBounds(containing point: CGPoint) -> CGRect? {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else { return nil }
        return displays.prefix(Int(displayCount))
            .map(CGDisplayBounds)
            .first(where: { $0.contains(point) })
    }
}
