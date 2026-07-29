//
//  DocumentResult.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Everything read from one file.
///
/// ```swift
/// let result = try await DocumentReader.read(contentsOf: url)
/// print(result.markdown)
/// print("\(result.pageCount) pages in \(result.duration)s")
/// ```
public struct DocumentResult: Sendable, Codable {

    /// The file that was read.
    public let url: URL

    /// The pages, in order.
    public let pages: [DocumentPage]

    /// Total time taken.
    public let duration: TimeInterval

    public init(url: URL, pages: [DocumentPage], duration: TimeInterval) {
        self.url = url
        self.pages = pages
        self.duration = duration
    }

    /// Number of pages read.
    public var pageCount: Int { pages.count }

    /// The whole document as Markdown, pages separated by a horizontal rule.
    public var markdown: String {
        pages.map(\.markdown).joined(separator: "\n\n---\n\n")
    }

    /// The whole document as plain text.
    public var plainText: String {
        pages.map(\.plainText).joined(separator: "\n\n")
    }

    /// Every table across every page.
    public var tables: [DocumentTable] { pages.flatMap(\.tables) }

    /// Every list across every page.
    public var lists: [DocumentList] { pages.flatMap(\.lists) }

    /// Detected data across every page, de-duplicated.
    ///
    /// A phone number in a letterhead repeats on every page; reporting it once is almost always
    /// what a caller wants.
    public var detectedData: [DetectedDataItem] {
        var seen = Set<String>()
        return pages.flatMap(\.detectedData).filter {
            seen.insert("\($0.kind.rawValue):\($0.value)").inserted
        }
    }

    /// True when every page came from an embedded text layer rather than recognition.
    ///
    /// A born-digital PDF: the text is exact, and nothing was guessed.
    public var isBornDigital: Bool {
        !pages.isEmpty && pages.allSatisfy { $0.source == .textLayer }
    }
}
