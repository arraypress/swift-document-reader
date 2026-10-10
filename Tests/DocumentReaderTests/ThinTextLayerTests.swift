//
//  ThinTextLayerTests.swift
//  DocumentReaderTests
//
//  Created by David Sherlock on 2026.
//
//  A page whose text layer is too thin to trust over recognition, and whose
//  picture recognition reads nothing from: the text layer is the answer.
//  Found on a LibreOffice cover page — "￼ ￼ 1 V994" in its text layer,
//  nothing for OCR to see — which `extract` reported as "No text found".
//

import CoreGraphics
import CoreText
import XCTest
@testable import DocumentReader

final class ThinTextLayerTests: XCTestCase {

    /// A one-page PDF carrying a few words in invisible ink: a text layer,
    /// and a blank picture.
    private func invisibleTextPDF(_ text: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("thin-\(UUID().uuidString).pdf")
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let context = CGContext(url as CFURL, mediaBox: &box, nil)!
        context.beginPDFPage(nil)
        context.setTextDrawingMode(.invisible)
        context.textPosition = CGPoint(x: 72, y: 700)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 14, nil)])), context)
        context.endPDFPage()
        context.closePDF()
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testAThinTextLayerIsKeptWhenRecognitionFindsNothing() async throws {
        let url = invisibleTextPDF("V994 page 1")
        XCTAssertFalse(TextLayer.isMeaningful("V994 page 1"), "under the bar, so recognition is tried first")

        let result = try await DocumentReader.read(contentsOf: url)
        XCTAssertEqual(result.pages.first?.source, .textLayer)
        XCTAssertTrue(result.plainText.contains("V994"), "got: \(result.plainText)")

        let pages = try await DocumentReader.text(contentsOf: url)
        XCTAssertEqual(pages.first?.source, .textLayer)
        XCTAssertTrue(pages.first?.text.contains("V994") == true)
    }

    func testObjectPlaceholdersAreNotText() {
        XCTAssertEqual(TextLayer.cleaned("\u{FFFC}\n\u{FFFC}\n1\nV994"), "1\nV994")
        // Sixteen placeholders and nothing else is not a text layer.
        XCTAssertFalse(TextLayer.isMeaningful(String(repeating: "\u{FFFC}", count: 16)))
        XCTAssertTrue(TextLayer.isMeaningful("A line of real words, long enough"))
    }
}
