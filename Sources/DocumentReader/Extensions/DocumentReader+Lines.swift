//
//  DocumentReader+Lines.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension DocumentReader {

    /// The text of each page, without structure.
    ///
    /// A PDF page with a meaningful text layer is read from it — those characters are exact and
    /// no recogniser improves on them — unless ``ReaderOptions/preferTextLayer`` is off. Every
    /// other page is recognised as lines. Decided **per page**, so a digital report with a
    /// scanned appendix comes back as text-layer pages followed by recognised ones, rather than
    /// the appendix hiding behind the pages that had text.
    ///
    /// ```swift
    /// for page in try await DocumentReader.text(contentsOf: url) {
    ///     print(page.source, page.text)
    /// }
    /// ```
    ///
    /// - Throws: ``DocumentReaderError`` if the file cannot be opened or has no pages.
    static func text(
        contentsOf url: URL,
        options: ReaderOptions = ReaderOptions()
    ) async throws -> [TextPage] {
        try await readLines(url, options: options, allowTextLayer: true)
    }

    /// Every page recognised as lines, each with a confidence and a position.
    ///
    /// Always recognises, even where a PDF has a text layer: the layer carries characters but no
    /// line geometry, and the geometry is the point — finding a value by where it sits rather
    /// than by what precedes it.
    ///
    /// - Throws: ``DocumentReaderError`` if the file cannot be opened or has no pages.
    static func lines(
        contentsOf url: URL,
        options: ReaderOptions = ReaderOptions()
    ) async throws -> [TextPage] {
        try await readLines(url, options: options, allowTextLayer: false)
    }

    /// The barcodes and QR codes on every page.
    ///
    /// - Throws: ``DocumentReaderError`` if the file cannot be opened or has no pages.
    static func barcodes(
        contentsOf url: URL,
        options: ReaderOptions = ReaderOptions()
    ) async throws -> [DetectedBarcode] {
        var found: [DetectedBarcode] = []
        try await PageImages.forEach(in: url, options: options, allowTextLayer: false) { page in
            guard case .image(let number, let image, _) = page else { return }
            found += try await BarcodeDetector.barcodes(in: image, page: number)
        }
        return found
    }

    // MARK: - Plumbing

    private static func readLines(
        _ url: URL,
        options: ReaderOptions,
        allowTextLayer: Bool
    ) async throws -> [TextPage] {
        var pages: [TextPage] = []
        try await PageImages.forEach(in: url, options: options, allowTextLayer: allowTextLayer) { page in
            switch page {
            case .textLayer(let number, let text):
                pages.append(TextPage(pageNumber: number, text: text, source: .textLayer, lines: []))
            case .image(let number, let image, let thinText):
                let lines = try await LineRecognizer.lines(in: image, options: options)
                // Nothing recognised, but the text layer had a little real
                // text: that is the page's text, not an empty page.
                if lines.isEmpty, let thinText {
                    pages.append(TextPage(pageNumber: number, text: thinText, source: .textLayer, lines: []))
                    return
                }
                pages.append(TextPage(
                    pageNumber: number,
                    text: lines.map(\.text).joined(separator: "\n"),
                    source: .recognition,
                    lines: lines
                ))
            }
        }
        return pages
    }
}
