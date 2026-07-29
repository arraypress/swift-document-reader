//
//  DocumentPage.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One page of a document, or one image.
///
/// ```swift
/// let result = try await DocumentReader.read(contentsOf: url)
/// for page in result.pages {
///     print("Page \(page.pageNumber): \(page.blocks.count) blocks, \(page.tables.count) tables")
///     print(page.markdown)
/// }
/// ```
public struct DocumentPage: Sendable, Codable {

    /// 1-based page number. Always `1` for a single image.
    public let pageNumber: Int

    /// Everything on the page, in reading order.
    public let blocks: [DocumentBlock]

    /// The page title, if the recogniser identified one.
    public let title: String?

    /// Structured data found on the page — emails, phone numbers, dates, amounts.
    public let detectedData: [DetectedDataItem]

    /// How the page was read.
    public let source: PageSource

    /// Seconds spent on this page.
    public let duration: TimeInterval

    public init(
        pageNumber: Int,
        blocks: [DocumentBlock],
        title: String?,
        detectedData: [DetectedDataItem],
        source: PageSource,
        duration: TimeInterval
    ) {
        self.pageNumber = pageNumber
        self.blocks = blocks
        self.title = title
        self.detectedData = detectedData
        self.source = source
        self.duration = duration
    }

    /// Tables on the page.
    public var tables: [DocumentTable] {
        blocks.compactMap { if case .table(let t) = $0.kind { return t } else { return nil } }
    }

    /// Lists on the page.
    public var lists: [DocumentList] {
        blocks.compactMap { if case .list(let l) = $0.kind { return l } else { return nil } }
    }

    /// Every word with its own frame, for building a searchable text layer.
    public var words: [RecognizedWord] {
        blocks.compactMap(\.words).flatMap { $0 }
    }

    /// All the page's text, in reading order.
    public var plainText: String {
        blocks.map(\.text).joined(separator: "\n\n")
    }

    /// The page as Markdown.
    public var markdown: String {
        MarkdownRenderer.render(blocks: blocks)
    }
}

// MARK: - Page Source

/// How a page's text was obtained.
///
/// Worth surfacing, because the two are not equally trustworthy: a PDF's own text layer is
/// exactly what the author typed, while OCR is a best guess from pixels. A caller deciding
/// whether to trust a figure — an invoice total, a reference number — reasonably wants to know
/// which it is looking at.
public enum PageSource: String, Sendable, Codable {

    /// Read from the PDF's embedded text layer. No recognition involved, so the characters are
    /// exact.
    case textLayer

    /// Recognised from pixels with Vision.
    case recognition
}
