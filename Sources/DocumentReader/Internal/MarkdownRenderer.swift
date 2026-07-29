//
//  MarkdownRenderer.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Renders blocks as Markdown.
///
/// Deliberately a separate step from ``BlockBuilder``, not folded into it. The blocks are the
/// library's real output — they carry geometry, which Markdown cannot — so a caller building a
/// searchable PDF, a JSON export or a custom format works from the same structure without
/// paying for a rendering it will throw away.
enum MarkdownRenderer {

    /// Renders blocks as a Markdown document.
    static func render(blocks: [DocumentBlock]) -> String {
        blocks.compactMap(render).joined(separator: "\n\n")
    }

    // MARK: - Blocks

    private static func render(_ block: DocumentBlock) -> String? {
        switch block.kind {
        case .heading(let level):
            let hashes = String(repeating: "#", count: max(1, min(level, 6)))
            return "\(hashes) \(block.text)"

        case .paragraph:
            return block.text.isEmpty ? nil : block.text

        case .list(let list):
            return render(list)

        case .table(let table):
            return render(table)
        }
    }

    private static func render(_ list: DocumentList) -> String? {
        guard !list.items.isEmpty else { return nil }
        return list.items.enumerated().map { index, item in
            list.style == .ordered ? "\(index + 1). \(item.text)" : "- \(item.text)"
        }.joined(separator: "\n")
    }

    private static func render(_ table: DocumentTable) -> String? {
        guard let header = table.rows.first, !header.isEmpty else { return nil }

        var lines = [row(header)]
        lines.append("|" + String(repeating: " --- |", count: header.count))
        for cells in table.rows.dropFirst() {
            lines.append(row(padded(cells, to: header.count)))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Table Helpers

    private static func row(_ cells: [DocumentTable.Cell]) -> String {
        "| " + cells.map { escaped($0.text) }.joined(separator: " | ") + " |"
    }

    /// Pads a short row out to the header width.
    ///
    /// Recognition can return a row with fewer cells than the header when a value is missed.
    /// Markdown renderers treat a row with the wrong column count as malformed and will drop or
    /// mangle it, so the gap is made explicit rather than left to corrupt the whole table.
    private static func padded(_ cells: [DocumentTable.Cell], to width: Int) -> [DocumentTable.Cell] {
        guard cells.count < width else { return Array(cells.prefix(width)) }
        return cells + Array(repeating: DocumentTable.Cell(text: ""), count: width - cells.count)
    }

    /// Escapes a cell so its contents cannot break the table.
    ///
    /// A literal pipe inside a cell — a units column, a file path — ends the cell early and
    /// shifts every value after it into the wrong column.
    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
