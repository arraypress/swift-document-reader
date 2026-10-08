//
//  DocumentTable+Tabular.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension DocumentTable {

    /// Whether this is a table rather than prose Vision took for one: at least two columns
    /// carrying content on more than one row.
    ///
    /// ```swift
    /// let tables = result.tables.filter(\.isTabular)
    /// ```
    var isTabular: Bool {
        TableShape.isTabular(rows.map { $0.map(\.text) })
    }
}
