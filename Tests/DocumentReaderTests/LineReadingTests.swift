//
//  LineReadingTests.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//
//  Lines, text and barcodes, end to end on pages rendered here — so the
//  expected answer is known exactly and anything short of it means the
//  wiring is wrong, not that OCR is hard.
//

import AppKit
import CoreImage
import PDFKit
import XCTest
@testable import DocumentReader

final class LineReadingTests: XCTestCase {

    // MARK: - Recognition

    func testCleanTextIsReadExactly() async throws {
        let wanted = "Invoice INV-2024-0871 total GBP 1,284.50"
        let url = try Self.imageFile(wanted, size: 22)
        defer { try? FileManager.default.removeItem(at: url) }

        var options = ReaderOptions()
        options.recognitionLanguages = ["en-US"]
        let read = try await DocumentReader.lines(contentsOf: url, options: options)
        let page = try XCTUnwrap(read.first)

        XCTAssertEqual(page.lines.map(\.text).joined(separator: " "), wanted)
        XCTAssertGreaterThan(page.confidence ?? 0, 0.5)
        XCTAssertEqual(page.source, .recognition)
    }

    /// Vision reports position bottom-left and normalised. Kept rather than flipped, so a caller
    /// comparing against Vision elsewhere sees the same numbers.
    func testLinePositionsAreNormalisedAndBottomLeft() async throws {
        let url = try Self.imageFile("Top line\nBottom line", size: 20)
        defer { try? FileManager.default.removeItem(at: url) }

        let lines = try await DocumentReader.lines(contentsOf: url).flatMap(\.lines)
        XCTAssertEqual(lines.count, 2)
        for line in lines {
            XCTAssertTrue((0...1).contains(line.frame.minX), "x normalised: \(line.frame.minX)")
            XCTAssertTrue((0...1).contains(line.frame.minY), "y normalised: \(line.frame.minY)")
        }
        let top = try XCTUnwrap(lines.first { $0.text.contains("Top") })
        let bottom = try XCTUnwrap(lines.first { $0.text.contains("Bottom") })
        XCTAssertGreaterThan(top.frame.minY, bottom.frame.minY, "origin is bottom-left")
    }

    /// A blank page has nothing on it, and inventing something would be worse than saying so.
    func testABlankPageRecognisesNothing() async throws {
        let url = try Self.imageFile("", size: 20)
        defer { try? FileManager.default.removeItem(at: url) }

        let read = try await DocumentReader.lines(contentsOf: url)
        let page = try XCTUnwrap(read.first)
        XCTAssertTrue(page.lines.isEmpty, "got: \(page.lines.map(\.text))")
        XCTAssertNil(page.confidence)
    }

    // MARK: - Text layer

    func testARealTextLayerIsReadNotRecognised() async throws {
        let url = try Self.textPDF(["The quick brown fox jumps over the lazy dog."])
        defer { try? FileManager.default.removeItem(at: url) }

        let read = try await DocumentReader.text(contentsOf: url)
        let page = try XCTUnwrap(read.first)
        XCTAssertEqual(page.source, .textLayer)
        XCTAssertTrue(page.text.contains("quick brown fox"))
        XCTAssertNil(page.confidence, "exact text has nothing to be uncertain about")
        XCTAssertTrue(page.lines.isEmpty, "a text layer carries no line geometry")
    }

    /// Per page: a digital page followed by a scanned one comes back as one of each, rather
    /// than the scan hiding behind the page that had text.
    func testAScannedPageInADigitalFileIsRecognised() async throws {
        let url = try Self.textPDF(["The quick brown fox jumps over the lazy dog.", ""])
        defer { try? FileManager.default.removeItem(at: url) }

        let pages = try await DocumentReader.text(contentsOf: url)
        XCTAssertEqual(pages.map(\.source), [.textLayer, .recognition])
    }

    func testTheTextLayerCanBeRefused() async throws {
        let url = try Self.textPDF(["The quick brown fox jumps over the lazy dog."])
        defer { try? FileManager.default.removeItem(at: url) }

        var options = ReaderOptions()
        options.preferTextLayer = false
        let read = try await DocumentReader.text(contentsOf: url, options: options)
        let page = try XCTUnwrap(read.first)
        XCTAssertEqual(page.source, .recognition)
    }

    func testLinesAlwaysRecogniseEvenWithATextLayer() async throws {
        let url = try Self.textPDF(["The quick brown fox jumps over the lazy dog."])
        defer { try? FileManager.default.removeItem(at: url) }

        let read = try await DocumentReader.lines(contentsOf: url)
        let page = try XCTUnwrap(read.first)
        XCTAssertEqual(page.source, .recognition)
        XCTAssertFalse(page.lines.isEmpty)
    }

    func testThePageRangeIsHonoured() async throws {
        let url = try Self.textPDF(["Page one says something long enough.", "Page two says something long enough."])
        defer { try? FileManager.default.removeItem(at: url) }

        var options = ReaderOptions()
        options.pageRange = [2]
        let pages = try await DocumentReader.text(contentsOf: url, options: options)
        XCTAssertEqual(pages.map(\.pageNumber), [2])
    }

    // MARK: - Barcodes

    func testAQRCodeIsRead() async throws {
        let url = try Self.qrFile("https://example.com/parcel/42")
        defer { try? FileManager.default.removeItem(at: url) }

        let codes = try await DocumentReader.barcodes(contentsOf: url)
        XCTAssertEqual(codes.map(\.payload), ["https://example.com/parcel/42"])
        XCTAssertEqual(codes.first?.pageNumber, 1)
    }

    // MARK: - Failures

    func testAFileThatIsNeitherIsRefused() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("reader-\(UUID().uuidString).txt")
        try "not a document".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await DocumentReader.text(contentsOf: url)
            XCTFail("read a text file as a document")
        } catch let error as DocumentReaderError {
            XCTAssertEqual(error, .unreadableFile(url))
        }
    }

    /// A PDF is known by its header, not its name — and an image is never handed to PDFKit,
    /// which logs an error to stderr for every picture it is asked about.
    func testAPDFIsKnownByItsHeader() throws {
        let pdf = try Self.textPDF(["The quick brown fox jumps over the lazy dog."])
        let renamed = pdf.deletingPathExtension().appendingPathExtension("bin")
        try FileManager.default.moveItem(at: pdf, to: renamed)
        let image = try Self.imageFile("hello", size: 20)
        defer {
            try? FileManager.default.removeItem(at: renamed)
            try? FileManager.default.removeItem(at: image)
        }

        XCTAssertTrue(PDFProbe.isPDF(renamed))
        XCTAssertFalse(PDFProbe.isPDF(image))
        XCTAssertNil(PDFProbe.document(at: image))
    }

    // MARK: - Table shape

    func testProseThatHappensToLineUpIsNotATable() {
        let prose = [
            ["", "The quarterly figures were revised after"],
            ["", "the audit, and the revision is reflected"],
            ["", "in every total below."],
        ]
        XCTAssertFalse(TableShape.isTabular(prose), "only one column carries content on more than one row")
    }

    func testARealTableIsKept() {
        XCTAssertTrue(TableShape.isTabular([["Item", "Total"], ["Widget", "4.50"], ["Gadget", "1.25"]]))
    }

    func testASparseTableSurvives() {
        XCTAssertTrue(TableShape.isTabular([["Subtotal", "", "10.00"], ["Tax", "", "2.00"], ["", "Total", "12.00"]]))
    }

    func testOneRowOrOneColumnIsNotATable() {
        XCTAssertFalse(TableShape.isTabular([["Item", "Total"]]), "a header with no body")
        XCTAssertFalse(TableShape.isTabular([["a"], ["b"], ["c"]]), "a single column is a list")
        XCTAssertFalse(TableShape.isTabular([]))
    }

    func testTheModelDelegatesToTheRule() {
        let table = DocumentTable(rows: [[.init(text: "a"), .init(text: "b")], [.init(text: "c"), .init(text: "d")]])
        XCTAssertTrue(table.isTabular)
    }

    // MARK: - Fixtures

    private static func temporary(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-test-\(UUID().uuidString)")
            .appendingPathExtension(ext)
    }

    /// Text drawn black on white and saved as a PNG. An empty string gives a blank page.
    private static func imageFile(_ text: String, size: CGFloat) throws -> URL {
        let font = NSFont(name: "Helvetica", size: size) ?? .systemFont(ofSize: size)
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.black])
        let measured = attributed.boundingRect(with: NSSize(width: 1200, height: 800), options: [.usesLineFragmentOrigin])
        let canvas = NSSize(width: max(measured.width, 340) + 60, height: max(measured.height, 140) + 60)
        let image = NSImage(size: canvas)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: canvas).fill()
        attributed.draw(with: NSRect(x: 30, y: 30, width: measured.width, height: measured.height),
                        options: [.usesLineFragmentOrigin])
        image.unlockFocus()
        return try write(image)
    }

    private static func qrFile(_ payload: String) throws -> URL {
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        let code = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let padded = code.transformed(by: CGAffineTransform(translationX: 40, y: 40))
            .composited(over: CIImage(color: .white).cropped(to: code.extent.insetBy(dx: -40, dy: -40).offsetBy(dx: 40, dy: 40)))
        let url = temporary("png")
        try CIContext().writePNGRepresentation(of: padded, to: url, format: .RGBA8,
                                               colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        return url
    }

    private static func write(_ image: NSImage) throws -> URL {
        var rect = NSRect(origin: .zero, size: image.size)
        let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
        let url = temporary("png")
        try NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    /// A PDF with genuine text drawn into it, one page per string. An empty string gives a page
    /// with nothing on it — a scan, as far as the text layer is concerned.
    private static func textPDF(_ bodies: [String]) throws -> URL {
        let url = temporary("pdf")
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let font = CTFontCreateWithName("Helvetica" as CFString, 16, nil)
        for body in bodies {
            context.beginPDFPage(nil)
            if !body.isEmpty {
                let attributed = NSAttributedString(string: body, attributes: [.font: font, .foregroundColor: NSColor.black])
                let setter = CTFramesetterCreateWithAttributedString(attributed)
                let path = CGPath(rect: CGRect(x: 50, y: 640, width: 495, height: 140), transform: nil)
                CTFrameDraw(CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, nil), context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }
}
