//
//  PageImages.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation
import PDFKit

/// The pages of a file, one at a time, as images or as text-layer strings.
///
/// Shared by every reading path so that page selection, the empty-document check and the
/// "unreadable" refusal behave the same whichever kind of reading asked.
enum PageImages {

    /// One page: its number, and either its text layer or its image.
    enum Page {
        case textLayer(number: Int, text: String)
        case image(number: Int, image: CGImage)
    }

    /// Walks the selected pages of `url`, calling `body` with each.
    ///
    /// - Parameters:
    ///   - url: A PDF, or any image ImageIO can open.
    ///   - options: Page range, render scale, and whether a text layer may be used.
    ///   - allowTextLayer: Whether a meaningful text layer is handed over instead of an image.
    static func forEach(
        in url: URL,
        options: ReaderOptions,
        allowTextLayer: Bool,
        _ body: (Page) async throws -> Void
    ) async throws {
        if let pdf = PDFProbe.document(at: url) {
            guard pdf.pageCount > 0 else { throw DocumentReaderError.emptyDocument(url) }
            for index in 0..<pdf.pageCount {
                let number = index + 1
                guard options.pageRange.isEmpty || options.pageRange.contains(number) else { continue }
                try Task.checkCancellation()
                guard let page = pdf.page(at: index) else { continue }

                if allowTextLayer, options.preferTextLayer, let text = page.string,
                   TextLayer.isMeaningful(text) {
                    try await body(.textLayer(number: number, text: text))
                    continue
                }
                guard let image = PageRasterizer.render(page: page, scale: options.renderScale) else {
                    throw DocumentReaderError.renderFailed(page: number)
                }
                try await body(.image(number: number, image: image))
            }
            return
        }

        guard let image = PageRasterizer.image(at: url) else {
            throw DocumentReaderError.unreadableFile(url)
        }
        try await body(.image(number: 1, image: image))
    }
}

// MARK: - Text Layer

/// Whether a PDF's text layer is worth using.
enum TextLayer {

    /// Scanned PDFs frequently carry an empty or near-empty text layer — a few stray characters
    /// from a failed OCR pass, or whitespace alone. Taking that at face value returns a blank
    /// page for a document that recognises perfectly well, so anything this thin falls through
    /// to recognition instead.
    static func isMeaningful(_ text: String) -> Bool {
        text.trimmed.count >= minimumCharacters
    }

    static let minimumCharacters = 16
}
