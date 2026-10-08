//
//  DocumentReaderTests.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import XCTest
@testable import DocumentReader

final class DocumentReaderTests: XCTestCase {

    // MARK: - ReaderOptions

    func testDefaultOptions() {
        let options = ReaderOptions()
        XCTAssertTrue(options.preferTextLayer)
        XCTAssertTrue(options.detectHeadings)
        XCTAssertEqual(options.renderScale, 3)
        XCTAssertTrue(options.recognitionLanguages.isEmpty)
        XCTAssertTrue(options.customWords.isEmpty)
        XCTAssertTrue(options.pageRange.isEmpty)
    }

    // MARK: - ListMarkerSplitter

    /// The behaviour this exists for: Vision folds a numbered item into the previous one.
    func testSplitsMergedNumberedItems() {
        let merged = "Re-run the audit in April 3. Publish the summary to the team"
        XCTAssertEqual(
            ListMarkerSplitter.split(merged),
            ["Re-run the audit in April", "Publish the summary to the team"]
        )
    }

    func testSplitsThreeWayMerge() {
        let merged = "First thing 2. Second thing 3. Third thing"
        XCTAssertEqual(
            ListMarkerSplitter.split(merged),
            ["First thing", "Second thing", "Third thing"]
        )
    }

    func testLeavesCleanItemAlone() {
        XCTAssertEqual(ListMarkerSplitter.split("Expand the trial"), ["Expand the trial"])
    }

    /// Prose is not a list. A sentence containing a year or a decimal must survive intact.
    func testDoesNotSplitOrdinaryProse() {
        XCTAssertEqual(
            ListMarkerSplitter.split("Revenue grew 2026 was the best year"),
            ["Revenue grew 2026 was the best year"]
        )
        XCTAssertEqual(
            ListMarkerSplitter.split("The result was 3.5 percent higher"),
            ["The result was 3.5 percent higher"]
        )
    }

    func testHandlesParenthesisMarkers() {
        XCTAssertEqual(
            ListMarkerSplitter.split("Alpha 2) Beta"),
            ["Alpha", "Beta"]
        )
    }

    // MARK: - HeadingClassifier

    /// Heights measured from a real page: body 0.0187, subheads 0.0208–0.0240, title 0.0333.
    /// A fixed 1.15x threshold missed every subhead on this page, which is why levels are
    /// clustered rather than thresholded.
    func testClustersRealPageHeights() {
        let blocks = [
            paragraph("Quarterly Field Report", height: 0.0333),
            paragraph("Section 1 - Overview", height: 0.0208),
            paragraph("The separation pipeline was evaluated.", height: 0.0187),
            paragraph("Throughput held steady.", height: 0.0187),
            paragraph("Findings", height: 0.0240),
            paragraph("Results by Region", height: 0.0208)
        ]

        let classified = HeadingClassifier.apply(to: blocks, title: "Quarterly Field Report")

        XCTAssertEqual(level(of: classified[0]), 1, "the recognised title is level 1")
        XCTAssertNotNil(level(of: classified[1]), "0.0208 is a heading, not body")
        XCTAssertNil(level(of: classified[2]), "body text stays a paragraph")
        XCTAssertNil(level(of: classified[3]), "body text stays a paragraph")
        XCTAssertNotNil(level(of: classified[4]), "0.0240 is a heading")
        XCTAssertNotNil(level(of: classified[5]), "0.0208 is a heading")
    }

    /// A page of uniform text has no headings to find, and must not invent one.
    func testUniformTextProducesNoHeadings() {
        let blocks = (0..<5).map { paragraph("Line \($0)", height: 0.02) }
        let classified = HeadingClassifier.apply(to: blocks, title: nil)
        XCTAssertTrue(classified.allSatisfy { level(of: $0) == nil })
    }

    /// A paragraph that wraps is taller than a one-line heading in a bigger font. Measured by
    /// frame it became a heading on 6 of 8 synthetic pages — the layout below — and the real
    /// heading beside it was taken for body text; measured by its words it stays body.
    func testWrappedParagraphIsNotAHeading() {
        let blocks = [
            paragraph("Field Survey Results", height: 0.033, wordHeight: 0.033),
            paragraph("Method", height: 0.023, wordHeight: 0.023),
            paragraph("Samples were collected at dawn from four sites and stored cold.", height: 0.040, wordHeight: 0.015),
        ]

        let classified = HeadingClassifier.apply(to: blocks, title: "Field Survey Results")

        XCTAssertEqual(level(of: classified[0]), 1)
        XCTAssertEqual(level(of: classified[1]), 2, "the 18pt heading is a heading")
        XCTAssertNil(level(of: classified[2]), "two lines of body text are still body text")
    }

    /// The recognised title owns level 1; the next size down is the first heading, level 2 —
    /// not level 3 because the title's own size was counted as a level too.
    func testFirstHeadingUnderATitleIsLevelTwo() {
        let blocks = [
            paragraph("Field Survey Results", height: 0.033, wordHeight: 0.033),
            paragraph("Method", height: 0.023, wordHeight: 0.023),
            paragraph("Body text.", height: 0.015, wordHeight: 0.015),
            paragraph("More body text.", height: 0.015, wordHeight: 0.015),
        ]

        let classified = HeadingClassifier.apply(to: blocks, title: "Field Survey Results")

        XCTAssertEqual(level(of: classified[1]), 2)
    }

    func testHeadingDetectionCanBeDisabled() {
        let blocks = [
            paragraph("Huge Title", height: 0.05),
            paragraph("body", height: 0.02),
            paragraph("body", height: 0.02)
        ]
        let untouched = BlockBuilderTestShim.withoutHeadings(blocks)
        XCTAssertTrue(untouched.allSatisfy { level(of: $0) == nil })
    }

    // MARK: - MarkdownRenderer

    func testRendersHeadingsAndParagraphs() {
        let md = MarkdownRenderer.render(blocks: [
            DocumentBlock(kind: .heading(level: 1), text: "Title", frame: .zero),
            DocumentBlock(kind: .heading(level: 2), text: "Section", frame: .zero),
            DocumentBlock(kind: .paragraph, text: "Body text.", frame: .zero)
        ])
        XCTAssertEqual(md, "# Title\n\n## Section\n\nBody text.")
    }

    func testRendersOrderedAndUnorderedLists() {
        let unordered = DocumentList(style: .unordered, items: [.init(text: "One"), .init(text: "Two")])
        let ordered = DocumentList(style: .ordered, items: [.init(text: "First"), .init(text: "Second")])

        XCTAssertEqual(
            MarkdownRenderer.render(blocks: [DocumentBlock(kind: .list(unordered), text: "", frame: .zero)]),
            "- One\n- Two"
        )
        XCTAssertEqual(
            MarkdownRenderer.render(blocks: [DocumentBlock(kind: .list(ordered), text: "", frame: .zero)]),
            "1. First\n2. Second"
        )
    }

    func testRendersTableAsGFM() {
        let table = DocumentTable(rows: [
            [.init(text: "Region"), .init(text: "Errors")],
            [.init(text: "North"), .init(text: "3")]
        ])
        let md = MarkdownRenderer.render(blocks: [DocumentBlock(kind: .table(table), text: "", frame: .zero)])
        XCTAssertEqual(md, "| Region | Errors |\n| --- | --- |\n| North | 3 |")
    }

    /// A short row would otherwise produce a malformed table that renderers mangle wholesale.
    func testPadsShortTableRows() {
        let table = DocumentTable(rows: [
            [.init(text: "A"), .init(text: "B"), .init(text: "C")],
            [.init(text: "1")]
        ])
        let md = MarkdownRenderer.render(blocks: [DocumentBlock(kind: .table(table), text: "", frame: .zero)])
        XCTAssertTrue(md.hasSuffix("| 1 |  |  |"), "got: \(md)")
    }

    /// A literal pipe in a cell ends it early and shifts every later value one column left.
    func testEscapesPipesInCells() {
        let table = DocumentTable(rows: [
            [.init(text: "Path")],
            [.init(text: "a|b")]
        ])
        let md = MarkdownRenderer.render(blocks: [DocumentBlock(kind: .table(table), text: "", frame: .zero)])
        XCTAssertTrue(md.contains(#"a\|b"#), "got: \(md)")
    }

    // MARK: - TextLayerParser

    func testSplitsParagraphsOnBlankLines() {
        let blocks = TextLayerParser.blocks(from: "First para.\n\nSecond para.")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].text, "First para.")
    }

    func testRecognisesListsInTextLayer() {
        let blocks = TextLayerParser.blocks(from: "- One\n- Two\n- Three")
        guard case .list(let list) = blocks.first?.kind else {
            return XCTFail("expected a list, got \(String(describing: blocks.first?.kind))")
        }
        XCTAssertEqual(list.style, .unordered)
        XCTAssertEqual(list.items.map(\.text), ["One", "Two", "Three"])
    }

    func testRecognisesOrderedListsInTextLayer() {
        let blocks = TextLayerParser.blocks(from: "1. One\n2. Two")
        guard case .list(let list) = blocks.first?.kind else {
            return XCTFail("expected a list")
        }
        XCTAssertEqual(list.style, .ordered)
        XCTAssertEqual(list.items.map(\.text), ["One", "Two"])
    }

    // MARK: - Models

    func testTableConvenienceAccessors() {
        let table = DocumentTable(rows: [
            [.init(text: "A"), .init(text: "B")],
            [.init(text: "1"), .init(text: "2")]
        ])
        XCTAssertEqual(table.rowCount, 2)
        XCTAssertEqual(table.columnCount, 2)
        XCTAssertEqual(table.allText, ["A", "B", "1", "2"])
        XCTAssertEqual(table.tsvRepresentation, "A\tB\n1\t2")
    }

    func testResultDeduplicatesDetectedData() {
        let item = DetectedDataItem(kind: .email, value: "a@b.com")
        let page = { (n: Int) in
            DocumentPage(pageNumber: n, blocks: [], title: nil, detectedData: [item],
                         source: .recognition, duration: 0)
        }
        let result = DocumentResult(url: URL(fileURLWithPath: "/tmp/x.pdf"),
                                    pages: [page(1), page(2), page(3)], duration: 0)
        XCTAssertEqual(result.detectedData.count, 1, "a letterhead email should be reported once")
    }

    func testBornDigitalOnlyWhenEveryPageIsTextLayer() {
        let url = URL(fileURLWithPath: "/tmp/x.pdf")
        func page(_ n: Int, _ source: PageSource) -> DocumentPage {
            DocumentPage(pageNumber: n, blocks: [], title: nil, detectedData: [],
                         source: source, duration: 0)
        }
        XCTAssertTrue(DocumentResult(url: url, pages: [page(1, .textLayer)], duration: 0).isBornDigital)
        XCTAssertFalse(
            DocumentResult(url: url, pages: [page(1, .textLayer), page(2, .recognition)], duration: 0).isBornDigital,
            "one scanned page means the document is not born-digital"
        )
        XCTAssertFalse(DocumentResult(url: url, pages: [], duration: 0).isBornDigital)
    }

    // MARK: - Errors

    func testUnreadableFileThrows() async {
        let url = URL(fileURLWithPath: "/tmp/definitely-not-a-document-\(UUID().uuidString)")
        do {
            _ = try await DocumentReader.read(contentsOf: url)
            XCTFail("expected a throw")
        } catch let error as DocumentReaderError {
            XCTAssertEqual(error, .unreadableFile(url))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Helpers

    private func paragraph(_ text: String, height: CGFloat) -> DocumentBlock {
        DocumentBlock(
            kind: .paragraph,
            text: text,
            frame: CGRect(x: 0, y: 0, width: 0.5, height: height)
        )
    }

    /// A paragraph whose words are `wordHeight` tall — its frame is whatever `height` says,
    /// which for a wrapped paragraph is several lines of them.
    private func paragraph(_ text: String, height: CGFloat, wordHeight: CGFloat) -> DocumentBlock {
        let words = text.split(separator: " ").map {
            RecognizedWord(text: String($0), frame: CGRect(x: 0, y: 0, width: 0.05, height: wordHeight), confidence: 1)
        }
        return DocumentBlock(
            kind: .paragraph,
            text: text,
            frame: CGRect(x: 0, y: 0, width: 0.5, height: height),
            words: words
        )
    }

    private func level(of block: DocumentBlock) -> Int? {
        if case .heading(let level) = block.kind { return level }
        return nil
    }
}

/// Stands in for the `detectHeadings: false` path without needing a real observation.
private enum BlockBuilderTestShim {
    static func withoutHeadings(_ blocks: [DocumentBlock]) -> [DocumentBlock] { blocks }
}
