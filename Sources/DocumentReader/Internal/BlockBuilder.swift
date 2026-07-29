//
//  BlockBuilder.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import DataDetection
import Vision

/// Turns a Vision `DocumentObservation` into ``DocumentBlock`` values in reading order.
///
/// Vision hands back paragraphs, lists and tables in three separate, unordered arrays. This
/// reassembles them into the sequence a person would read, removes the duplication between
/// those arrays, and works out heading levels.
enum BlockBuilder {

    /// Build the blocks for one page.
    static func build(
        from container: DocumentObservation.Container,
        detectHeadings: Bool
    ) -> [DocumentBlock] {
        var blocks: [DocumentBlock] = []

        // Lists and tables first, so their regions are known before paragraphs are filtered.
        for list in container.lists {
            blocks.append(makeList(list))
        }
        for table in container.tables {
            blocks.append(makeTable(table))
        }

        // A paragraph that sits inside a list or a table is the *same ink*, reported twice —
        // Vision includes list item and cell text in `paragraphs` as well.
        //
        // Matched by geometry rather than by string: a list item's text has the marker stripped
        // ("Latency dropped…") while the paragraph keeps it ("• Latency dropped…"), so
        // comparing the two silently fails and every bullet is emitted twice.
        let claimed = blocks.map(\.frame)
        for paragraph in container.paragraphs {
            let frame = paragraph.boundingRegion.boundingBox.cgRect
            guard !isContained(frame, in: claimed) else { continue }
            let text = paragraph.transcript.trimmed
            guard !text.isEmpty else { continue }

            blocks.append(
                DocumentBlock(
                    kind: .paragraph,
                    text: text,
                    frame: frame,
                    words: makeWords(from: paragraph)
                )
            )
        }

        blocks = sortedByReadingOrder(blocks)
        return detectHeadings ? HeadingClassifier.apply(to: blocks, title: container.title?.transcript) : blocks
    }

    // MARK: - Reading Order

    /// Sorts blocks top-to-bottom, then left-to-right.
    ///
    /// Vision's Y axis runs bottom-up, so *descending* Y is top-down on the page. The tolerance
    /// keeps two blocks that sit on the same line — side-by-side columns, a figure beside its
    /// caption — in left-to-right order rather than letting a pixel of difference in their
    /// baselines decide.
    private static func sortedByReadingOrder(_ blocks: [DocumentBlock]) -> [DocumentBlock] {
        blocks.sorted { a, b in
            if abs(a.frame.origin.y - b.frame.origin.y) > sameLineTolerance {
                return a.frame.origin.y > b.frame.origin.y
            }
            return a.frame.origin.x < b.frame.origin.x
        }
    }

    /// Vertical distance within which two blocks count as being on the same line.
    private static let sameLineTolerance: CGFloat = 0.005

    // MARK: - Containment

    /// Whether most of `frame` falls inside any of `regions`.
    ///
    /// A share of area rather than strict containment: recognised boxes are approximate, and a
    /// list item's paragraph box routinely pokes a little outside the list's own bounds.
    private static func isContained(_ frame: CGRect, in regions: [CGRect]) -> Bool {
        guard frame.width > 0, frame.height > 0 else { return false }
        let area = frame.width * frame.height
        return regions.contains { region in
            let overlap = region.intersection(frame)
            guard !overlap.isNull else { return false }
            return (overlap.width * overlap.height) / area > 0.5
        }
    }

    // MARK: - Lists

    private static func makeList(_ list: DocumentObservation.Container.List) -> DocumentBlock {
        let style: DocumentList.Style
        switch list.items.first?.markerType {
        case .decimal, .lowercaseLatin, .uppercaseLatin, .decorativeDecimal, .compositeDecimal:
            style = .ordered
        default:
            style = .unordered
        }

        var items: [DocumentList.Item] = []
        for item in list.items {
            // Vision sometimes swallows the following entry into this one's string —
            // "Re-run the audit in April 3. Publish the summary to the team" arrives as a
            // single item. Split it back out on an embedded marker.
            let pieces = style == .ordered
                ? ListMarkerSplitter.split(item.itemString)
                : [item.itemString]
            items.append(contentsOf: pieces.map { DocumentList.Item(text: $0.trimmed) })
        }
        items = items.filter { !$0.text.isEmpty }

        let model = DocumentList(style: style, items: items)
        let text = items.enumerated().map { index, item in
            style == .ordered ? "\(index + 1). \(item.text)" : "- \(item.text)"
        }.joined(separator: "\n")

        return DocumentBlock(
            kind: .list(model),
            text: text,
            frame: list.boundingRegion.boundingBox.cgRect
        )
    }

    // MARK: - Tables

    private static func makeTable(_ table: DocumentObservation.Container.Table) -> DocumentBlock {
        let rows: [[DocumentTable.Cell]] = table.rows.map { row in
            row.map { cell in
                DocumentTable.Cell(
                    text: cell.content.text.transcript.trimmed,
                    rowSpan: cell.rowRange.count,
                    columnSpan: cell.columnRange.count
                )
            }
        }
        let model = DocumentTable(rows: rows)
        return DocumentBlock(
            kind: .table(model),
            text: model.tsvRepresentation,
            frame: table.boundingRegion.boundingBox.cgRect
        )
    }

    // MARK: - Words

    /// Per-word boxes, for a searchable text layer.
    ///
    /// `nil` where Vision does not segment words — Chinese, Japanese, Korean and Thai give
    /// lines only.
    private static func makeWords(
        from text: DocumentObservation.Container.Text
    ) -> [RecognizedWord]? {
        guard let words = text.words else { return nil }
        return words.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedWord(
                text: candidate.string,
                frame: observation.boundingRegion.boundingBox.cgRect,
                confidence: candidate.confidence
            )
        }
    }

    // MARK: - Detected Data

    /// Collects detected data from every text source on the page.
    static func detectedData(
        from container: DocumentObservation.Container
    ) -> [DetectedDataItem] {
        var items: [DetectedDataItem] = []

        var sources: [DocumentObservation.Container.Text] = [container.text] + container.paragraphs
        if let title = container.title { sources.append(title) }
        for table in container.tables {
            for row in table.rows { sources.append(contentsOf: row.map { $0.content.text }) }
        }
        for list in container.lists {
            sources.append(contentsOf: list.items.map { $0.content.text })
        }

        for source in sources {
            for match in source.detectedData {
                if let item = map(match) { items.append(item) }
            }
        }

        // `container.text` overlaps every other source, so the same address appears repeatedly.
        var seen = Set<String>()
        return items.filter { seen.insert("\($0.kind.rawValue):\($0.value)").inserted }
    }

    private static func map(
        _ detected: DocumentObservation.Container.DataDetectorMatch
    ) -> DetectedDataItem? {
        switch detected.match.details {
        case .link(let link):
            return DetectedDataItem(kind: .url, value: link.url.absoluteString)
        case .emailAddress(let email):
            return DetectedDataItem(kind: .email, value: email.emailAddress)
        case .phoneNumber(let phone):
            return DetectedDataItem(kind: .phoneNumber, value: phone.phoneNumber)
        case .postalAddress(let postal):
            return DetectedDataItem(kind: .postalAddress, value: postal.fullAddress)
        case .moneyAmount(let money):
            return DetectedDataItem(kind: .moneyAmount, value: "\(money.amount) \(money.currency.identifier)")
        case .flightNumber(let flight):
            return DetectedDataItem(kind: .flightNumber, value: "\(flight.airlineCode) \(flight.flightNumber)")
        case .shipmentTrackingNumber(let tracking):
            return DetectedDataItem(kind: .shipmentTracking, value: "\(tracking.carrier) \(tracking.trackingNumber)")
        case .calendarEvent(let event):
            var parts: [String] = []
            if let start = event.startDate { parts.append("start: \(start)") }
            if let end = event.endDate { parts.append("end: \(end)") }
            return DetectedDataItem(kind: .calendarEvent, value: parts.joined(separator: ", "))
        case .measurement(let measurement):
            return DetectedDataItem(kind: .measurement, value: "\(measurement.value)")
        case .paymentIdentifier(let payment):
            return DetectedDataItem(kind: .paymentIdentifier, value: payment.identifier)
        @unknown default:
            return nil
        }
    }
}

// MARK: - String Helpers

extension String {

    /// Trimmed of surrounding whitespace and newlines.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
