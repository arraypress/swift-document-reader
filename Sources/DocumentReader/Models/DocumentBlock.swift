//
//  DocumentBlock.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// One piece of a page, in reading order.
///
/// Vision returns paragraphs, lists and tables in three separate arrays with no interleaving,
/// so a page's actual running order has to be rebuilt from geometry. A ``DocumentBlock`` is the
/// result: the same content, sorted the way a person reads it, with the heading level already
/// worked out.
///
/// Every block keeps its ``frame``, so the same read can drive both a Markdown export and an
/// invisible text layer for a searchable PDF.
///
/// ```swift
/// for block in page.blocks {
///     switch block.kind {
///     case .heading(let level): print(String(repeating: "#", count: level) + " " + block.text)
///     case .paragraph:          print(block.text)
///     case .list(let list):     print(list.items.map(\.text).joined(separator: "\n"))
///     case .table(let table):   print(table.tsvRepresentation)
///     }
/// }
/// ```
public struct DocumentBlock: Sendable, Codable {

    /// What this block is.
    public enum Kind: Sendable, Codable, Equatable {

        /// A heading, with its level — 1 for the page title, 2 and 3 for subheadings.
        ///
        /// Vision does not report heading levels; there is no "this is an H2" in the API. The
        /// level here is inferred from text height relative to the page's body text — see
        /// ``HeadingClassifier``.
        case heading(level: Int)

        /// Ordinary body text.
        case paragraph

        /// A bulleted or numbered list.
        case list(DocumentList)

        /// A table with rows and columns.
        case table(DocumentTable)
    }

    /// What kind of block this is.
    public let kind: Kind

    /// The block's text.
    ///
    /// For lists and tables this is a flattened rendering, useful for search and previews. The
    /// structured form lives in the associated value on ``kind``.
    public let text: String

    /// Where the block sits on the page, normalised 0...1 with the origin at the bottom-left,
    /// matching Vision's coordinate space.
    public let frame: CGRect

    /// Words with their own frames, when the recogniser provided them.
    ///
    /// `nil` for scripts where Vision does not segment words — Chinese, Japanese, Korean and
    /// Thai return lines but not words. Needed for a searchable-PDF text layer, where each word
    /// is drawn invisibly over its own position.
    public let words: [RecognizedWord]?

    public init(kind: Kind, text: String, frame: CGRect, words: [RecognizedWord]? = nil) {
        self.kind = kind
        self.text = text
        self.frame = frame
        self.words = words
    }
}

// MARK: - Recognized Word

/// A single word and the box it occupies.
///
/// The unit a searchable PDF needs: draw this string, invisibly, at this position, and a PDF
/// reader can select and search text over the original scan.
public struct RecognizedWord: Sendable, Codable {

    /// The recognised text.
    public let text: String

    /// Normalised position on the page, origin bottom-left.
    public let frame: CGRect

    /// Recogniser confidence, 0...1.
    public let confidence: Float

    public init(text: String, frame: CGRect, confidence: Float) {
        self.text = text
        self.frame = frame
        self.confidence = confidence
    }
}

// MARK: - Document Table

/// A table detected on a page.
///
/// ```swift
/// for table in page.tables {
///     print("Table (\(table.rowCount)×\(table.columnCount)):")
///     for row in table.rows {
///         print(row.map(\.text).joined(separator: " | "))
///     }
/// }
/// ```
public struct DocumentTable: Sendable, Codable, Equatable {

    /// A single cell.
    public struct Cell: Sendable, Codable, Equatable {

        /// The cell's text.
        public let text: String

        /// Rows this cell spans. A plain cell spans one; a merged header spans several.
        public let rowSpan: Int

        /// Columns this cell spans.
        public let columnSpan: Int

        public init(text: String, rowSpan: Int = 1, columnSpan: Int = 1) {
            self.text = text
            self.rowSpan = rowSpan
            self.columnSpan = columnSpan
        }
    }

    /// Rows of cells.
    public let rows: [[Cell]]

    public init(rows: [[Cell]]) {
        self.rows = rows
    }

    /// Number of rows.
    public var rowCount: Int { rows.count }

    /// Number of columns, taken from the first row.
    public var columnCount: Int { rows.first?.count ?? 0 }

    /// Every cell's text, flattened.
    public var allText: [String] { rows.flatMap { $0.map(\.text) } }

    /// Tab-separated, for pasting into a spreadsheet.
    public var tsvRepresentation: String {
        rows.map { $0.map(\.text).joined(separator: "\t") }.joined(separator: "\n")
    }
}

// MARK: - Document List

/// A bulleted or numbered list.
public struct DocumentList: Sendable, Codable, Equatable {

    /// How a list is marked, which decides whether it renders as `-` or `1.`.
    public enum Style: String, Sendable, Codable {

        /// Bullets, hyphens or any other unordered marker.
        case unordered

        /// Numbers or letters, where the sequence carries meaning.
        case ordered
    }

    /// One entry.
    public struct Item: Sendable, Codable, Equatable {

        /// The item's text, with the marker removed.
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }

    /// Whether the list is ordered.
    public let style: Style

    /// The entries, in order.
    public let items: [Item]

    public init(style: Style, items: [Item]) {
        self.style = style
        self.items = items
    }

    /// Number of entries.
    public var count: Int { items.count }
}
