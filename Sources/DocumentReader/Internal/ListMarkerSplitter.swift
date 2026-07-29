//
//  ListMarkerSplitter.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Splits list items that the recogniser merged.
///
/// `RecognizeDocumentsRequest` reliably separates bulleted items but not always numbered ones.
/// A three-item list can come back as two, with the third folded into the second:
///
/// ```
/// 1. Expand the trial to the northern sites
/// 2. Re-run the audit in April 3. Publish the summary to the team
///    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ two items, one string
/// ```
///
/// Reproduced across every layout and every recognition setting tried, so it is worth
/// correcting rather than waiting on. A marker appearing mid-string is a strong signal because
/// ordinary prose almost never contains " 3. " inside a sentence — and the split only ever runs
/// on lists the recogniser already reported as ordered.
enum ListMarkerSplitter {

    /// Splits an item on any embedded numeric marker.
    ///
    /// - Parameter item: One list item's text, marker already stripped by Vision.
    /// - Returns: One entry per item found. A string with no embedded marker comes back
    ///   unchanged, as a single element.
    static func split(_ item: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: separatorPattern) else { return [item] }

        let text = item as NSString
        let matches = regex.matches(in: item, range: NSRange(location: 0, length: text.length))
        guard !matches.isEmpty else { return [item] }

        var pieces: [String] = []
        var start = 0
        for match in matches {
            pieces.append(text.substring(with: NSRange(location: start, length: match.range.location - start)))
            start = match.range.location + match.range.length
        }
        pieces.append(text.substring(from: start))

        return pieces
            .map(stripLeadingMarker)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Whitespace immediately before a `1.`-style marker.
    ///
    /// Capped at two digits: a longer run is far more likely to be a year or a quantity than a
    /// list marker.
    private static let separatorPattern = #"\s(?=\d{1,2}[.)]\s)"#

    /// Removes the marker from the front of a split-off piece.
    private static func stripLeadingMarker(_ piece: String) -> String {
        piece.replacingOccurrences(
            of: #"^\s*\d{1,2}[.)]\s*"#,
            with: "",
            options: .regularExpression
        )
    }
}
