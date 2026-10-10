//
//  DocumentReader.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation
import PDFKit
import Vision

/// Reads documents and images into structured content — headings, paragraphs, lists and tables
/// in reading order, with the geometry kept.
///
/// Built on Apple's `RecognizeDocumentsRequest`, so everything runs on-device with no model to
/// ship, no network and no API key.
///
/// ```swift
/// let result = try await DocumentReader.read(contentsOf: url)
///
/// print(result.markdown)
///
/// for table in result.tables {
///     print(table.tsvRepresentation)
/// }
///
/// for word in result.pages[0].words {
///     // draw `word.text` invisibly at `word.frame` for a searchable PDF
/// }
/// ```
public enum DocumentReader {

    /// Reads a PDF or image file.
    ///
    /// Multi-page PDFs are read a page at a time — Vision has no batch API — and pages whose
    /// text is already embedded are taken from that text layer rather than recognised, unless
    /// ``ReaderOptions/preferTextLayer`` says otherwise.
    ///
    /// - Parameters:
    ///   - url: A PDF, or any image format ImageIO can open.
    ///   - options: How to read it.
    /// - Returns: The pages and their content.
    /// - Throws: ``DocumentReaderError`` if the file cannot be opened or has no pages.
    public static func read(
        contentsOf url: URL,
        options: ReaderOptions = ReaderOptions()
    ) async throws -> DocumentResult {
        let started = Date()

        if let pdf = PDFProbe.document(at: url) {
            guard pdf.pageCount > 0 else { throw DocumentReaderError.emptyDocument(url) }
            var pages: [DocumentPage] = []
            for index in 0..<pdf.pageCount {
                let number = index + 1
                guard options.pageRange.isEmpty || options.pageRange.contains(number) else { continue }
                try Task.checkCancellation()
                guard let page = pdf.page(at: index) else { continue }
                pages.append(try await read(page: page, number: number, options: options))
            }
            return DocumentResult(url: url, pages: pages, duration: Date().timeIntervalSince(started))
        }

        guard let image = PageRasterizer.image(at: url) else {
            throw DocumentReaderError.unreadableFile(url)
        }
        let page = try await read(image: image, number: 1, options: options)
        return DocumentResult(url: url, pages: [page], duration: Date().timeIntervalSince(started))
    }

    /// Reads a single already-loaded image — a screenshot, a camera frame, a cropped scan.
    ///
    /// - Parameters:
    ///   - image: The image to read.
    ///   - options: How to read it.
    /// - Returns: One page of content.
    public static func read(
        image: CGImage,
        options: ReaderOptions = ReaderOptions()
    ) async throws -> DocumentPage {
        try await read(image: image, number: 1, options: options)
    }

    // MARK: - Pages

    private static func read(
        page: PDFPage,
        number: Int,
        options: ReaderOptions
    ) async throws -> DocumentPage {
        let started = Date()

        // A born-digital PDF already contains exactly what the author typed. Recognising it
        // could only introduce errors, and costs a render plus a recognition pass to do so.
        let text = TextLayer.cleaned(page.string ?? "")
        func fromTextLayer() -> DocumentPage {
            DocumentPage(pageNumber: number, blocks: TextLayerParser.blocks(from: text), title: nil,
                         detectedData: [], source: .textLayer, duration: Date().timeIntervalSince(started))
        }
        if options.preferTextLayer, TextLayer.isMeaningful(text) { return fromTextLayer() }

        guard let image = PageRasterizer.render(page: page, scale: options.renderScale) else {
            throw DocumentReaderError.renderFailed(page: number)
        }
        let recognised = try await read(image: image, number: number, options: options)
        // A thin text layer is passed over for recognition — but when
        // recognition finds nothing, those few real characters are the page.
        if options.preferTextLayer, recognised.blocks.isEmpty, !text.isEmpty { return fromTextLayer() }
        return recognised
    }

    private static func read(
        image: CGImage,
        number: Int,
        options: ReaderOptions
    ) async throws -> DocumentPage {
        let started = Date()
        var request = RecognizeDocumentsRequest()

        // Load-bearing, and the single least discoverable thing in this library.
        //
        // The default minimum height silently discards short text: a table cell containing "3"
        // is simply never recognised, while "312" in the same cell at the same font size is.
        // It survives every render resolution from 2x to 6x and *which* cells vanish changes
        // between runs, so it presents as flaky OCR rather than as a setting. Measured on a
        // three-cell column: 1 of 3 recovered by default, 3 of 3 with this.
        request.textRecognitionOptions.minimumTextHeightFraction = 0

        if !options.recognitionLanguages.isEmpty {
            request.textRecognitionOptions.recognitionLanguages =
                options.recognitionLanguages.map { Locale.Language(identifier: $0) }
            request.textRecognitionOptions.automaticallyDetectLanguage = false
        }
        if !options.customWords.isEmpty {
            request.textRecognitionOptions.customWords = options.customWords
        }

        guard let container = try await request.perform(on: ImageEnhancer.prepared(image, options)).first?.document else {
            throw DocumentReaderError.recognitionFailed(page: number)
        }

        return DocumentPage(
            pageNumber: number,
            blocks: BlockBuilder.build(from: container, detectHeadings: options.detectHeadings),
            title: container.title?.transcript.trimmed,
            detectedData: BlockBuilder.detectedData(from: container),
            source: .recognition,
            duration: Date().timeIntervalSince(started)
        )
    }
}
