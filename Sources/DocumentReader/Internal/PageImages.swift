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
        /// A page to recognise, with what little its text layer held — too
        /// thin to trust over recognition, too real to throw away if
        /// recognition finds nothing.
        case image(number: Int, image: CGImage, thinText: String?)
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

                let text = TextLayer.cleaned(page.string ?? "")
                if allowTextLayer, options.preferTextLayer, TextLayer.isMeaningful(text) {
                    try await body(.textLayer(number: number, text: text))
                    continue
                }
                guard let image = PageRasterizer.render(page: page, scale: options.renderScale) else {
                    throw DocumentReaderError.renderFailed(page: number)
                }
                try await body(.image(number: number, image: image,
                                      thinText: allowTextLayer && !text.isEmpty ? text : nil))
            }
            return
        }

        guard let image = PageRasterizer.image(at: url) else {
            throw DocumentReaderError.unreadableFile(url)
        }
        try await body(.image(number: 1, image: image, thinText: nil))
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
        cleaned(text).count >= minimumCharacters
    }

    static let minimumCharacters = 16

    /// A text layer without what is not text: PDFKit writes U+FFFC, the
    /// object-replacement character, for every image or form object on the
    /// page, and a LibreOffice cover page came back as "￼ ￼ 1 V994" — two
    /// placeholders counted as characters, the real words too few to pass
    /// the bar, and then thrown away when recognition found nothing.
    static func cleaned(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{FFFC}", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
