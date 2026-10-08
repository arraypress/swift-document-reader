//
//  TextPage.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The text of one page, and how it was obtained.
///
/// What ``DocumentReader/text(contentsOf:options:)`` and
/// ``DocumentReader/lines(contentsOf:options:)`` return: text without structure, but with a
/// confidence and a position for every recognised line.
///
/// ```swift
/// for page in try await DocumentReader.text(contentsOf: url) {
///     print(page.pageNumber, page.source, page.confidence ?? 1)
///     print(page.text)
/// }
/// ```
public struct TextPage: Sendable, Codable {

    /// 1-based page number. Always `1` for a single image.
    public let pageNumber: Int

    /// The page's text, one line per line.
    public let text: String

    /// How the text was obtained. A text layer is exact; recognition is a best guess.
    public let source: PageSource

    /// The recognised lines, with their geometry. Empty for a text-layer page, which carries
    /// characters but no line positions.
    public let lines: [RecognizedLine]

    public init(pageNumber: Int, text: String, source: PageSource, lines: [RecognizedLine]) {
        self.pageNumber = pageNumber
        self.text = text
        self.source = source
        self.lines = lines
    }

    /// The mean of the lines' confidences — `nil` for a text-layer page, where there is nothing
    /// to be uncertain about and a 1.0 would be a number invented to fill a field.
    public var confidence: Double? {
        guard source == .recognition, !lines.isEmpty else { return nil }
        return lines.map(\.confidence).reduce(0, +) / Double(lines.count)
    }

    /// Lines of text on the page.
    public var lineCount: Int {
        source == .recognition ? lines.count : text.split(separator: "\n").count
    }
}
