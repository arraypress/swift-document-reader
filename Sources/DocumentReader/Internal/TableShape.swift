//
//  TableShape.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Whether a detected table is one.
///
/// Vision reports a table for prose that happens to line up. A scan of a plain paragraph came
/// back as two columns because one line wrapped and its second half sat under the first — six
/// rows with an empty left cell and a sentence on the right.
enum TableShape {

    /// A table has at least two columns carrying content on more than one row. One populated
    /// column is a list, or a paragraph, and calling it a table invites a caller to read a
    /// column that was never there.
    static func isTabular(_ rows: [[String]]) -> Bool {
        guard rows.count > 1 else { return false }
        let width = rows.map(\.count).max() ?? 0
        guard width > 1 else { return false }

        let populated = (0..<width).filter { column in
            rows.filter { row in
                column < row.count && !row[column].isEmpty
            }.count > 1
        }
        return populated.count > 1
    }
}
