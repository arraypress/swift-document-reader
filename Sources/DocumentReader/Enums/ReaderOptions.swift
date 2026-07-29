//
//  ReaderOptions.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How a document is read.
///
/// ```swift
/// var options = ReaderOptions()
/// options.preferTextLayer = false   // force OCR even on a born-digital PDF
/// options.detectHeadings = false    // screenshots have no heading hierarchy
/// let result = try await DocumentReader.read(contentsOf: url, options: options)
/// ```
public struct ReaderOptions: Sendable {

    /// Read a PDF's embedded text layer instead of recognising pixels, when one exists.
    ///
    /// On by default, and usually the right call: a born-digital PDF already contains exactly
    /// what the author typed, so recognising it can only introduce errors. Turn it off to force
    /// recognition — useful when a PDF's text layer is itself the output of bad OCR, which is
    /// common in documents that have been through a scanner-and-email round trip.
    public var preferTextLayer: Bool = true

    /// Work out heading levels from text size.
    ///
    /// Vision reports no heading levels, so they are inferred by comparing each block's height
    /// against the page's body text. That inference is meaningful for documents and meaningless
    /// for screenshots and UI captures, where large text is a button label rather than a
    /// heading — turn it off there and everything comes back as a paragraph.
    public var detectHeadings: Bool = true

    /// Scale factor used when rasterising a PDF page for recognition.
    ///
    /// 3x on a 72 dpi page is ~216 dpi, which measured cleanly across formats and degradation.
    /// Going higher does not help — at 6x recognition took nine times as long and recovered no
    /// extra text — while dropping below ~150 dpi equivalent starts losing short cells.
    public var renderScale: CGFloat = 3

    /// Languages to recognise, as BCP 47 tags. Empty means automatic.
    public var recognitionLanguages: [String] = []

    /// Words the recogniser should favour — product names, codes, jargon.
    public var customWords: [String] = []

    /// Pages to read, 1-based. Empty reads them all.
    public var pageRange: [Int] = []

    public init() {}
}
