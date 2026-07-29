//
//  TextLayerParser.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// Turns a PDF's embedded text into blocks.
///
/// A born-digital PDF hands over exactly what the author typed, which is strictly better than
/// recognising the same page from pixels. What it does not hand over is layout: `PDFPage.string`
/// is a flat run of text with no notion of a heading, a list or a table.
///
/// So this stays deliberately modest. Paragraphs are split on blank lines, and lines that
/// obviously carry a list marker are grouped — nothing is inferred about headings, because
/// there is no size information here to infer it from. Callers that need full structure from a
/// born-digital PDF should set ``ReaderOptions/preferTextLayer`` to `false` and let Vision read
/// the rendered page instead.
enum TextLayerParser {

    /// Splits a page's text into blocks.
    static func blocks(from text: String) -> [DocumentBlock] {
        let paragraphs = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        return paragraphs.compactMap { paragraph in
            let lines = paragraph.components(separatedBy: "\n").map { $0.trimmed }.filter { !$0.isEmpty }

            if lines.count > 1, lines.allSatisfy(startsWithMarker) {
                let ordered = lines.allSatisfy { $0.range(of: orderedMarker, options: .regularExpression) != nil }
                let items = lines.map { DocumentList.Item(text: strippingMarker($0)) }
                let list = DocumentList(style: ordered ? .ordered : .unordered, items: items)
                return DocumentBlock(kind: .list(list), text: paragraph, frame: .zero)
            }

            return DocumentBlock(kind: .paragraph, text: paragraph, frame: .zero)
        }
    }

    // MARK: - Markers

    private static let orderedMarker = #"^\s*\d{1,2}[.)]\s+"#

    /// Bullet characters written literally.
    ///
    /// `\u{2022}` is Swift's escape, not ICU's — inside a raw string it reaches
    /// `NSRegularExpression` as the four characters `\u{2` and silently matches nothing, so
    /// every bullet kept its marker. ICU wants `￿` with no braces; literal characters are
    /// clearer than either.
    private static let unorderedMarker = #"^\s*[•◦‣\-\*]\s+"#

    private static func startsWithMarker(_ line: String) -> Bool {
        line.range(of: orderedMarker, options: .regularExpression) != nil
            || line.range(of: unorderedMarker, options: .regularExpression) != nil
    }

    private static func strippingMarker(_ line: String) -> String {
        var stripped = line.replacingOccurrences(of: orderedMarker, with: "", options: .regularExpression)
        stripped = stripped.replacingOccurrences(of: unorderedMarker, with: "", options: .regularExpression)
        return stripped.trimmed
    }
}
