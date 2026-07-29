# Swift Document Reader

Read PDFs, scans and screenshots into **structured** content — headings, paragraphs, lists and tables in reading order, with the geometry kept. Built on Apple's `RecognizeDocumentsRequest`, so everything runs on-device: no model to ship, no network, no API keys, no third-party dependencies.

## Features

- 📄 **Structure, not just text** — headings, paragraphs, ordered/unordered lists, and tables with row/column spans
- 🔢 **Reading order rebuilt from geometry** — Vision returns paragraphs, lists and tables in three unordered arrays; blocks come back in the order a person reads them
- 📐 **Per-word boxes kept** — enough to draw an invisible text layer for a searchable PDF, from the same pass that gives you structure
- 📝 **Markdown out of the box** — or work from the block model and render it yourself
- 🧠 **Heading levels inferred** — Vision reports no heading level, so text heights are clustered per page
- ⚡ **Born-digital PDFs skip OCR** — the embedded text layer is exactly what the author typed, so recognising it could only introduce errors
- 🖼 **Any image format** — PNG, JPEG, HEIC, TIFF all decode identically; multi-page PDFs are read page by page
- 🔎 **Detected data** — emails, phone numbers, addresses, URLs, dates, currency and measurements, for free
- 🚫 **Cancellable** — respects `Task` cancellation between pages

## Requirements

- macOS 26.0+ / iOS 26.0+ / tvOS 26.0+
- Swift 6.2+

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-document-reader.git", from: "1.0.0")
```

## Usage

```swift
import DocumentReader

let result = try await DocumentReader.read(contentsOf: url)

print(result.markdown)

for table in result.tables {
    print(table.tsvRepresentation)
}

for word in result.pages[0].words {
    // draw word.text invisibly at word.frame for a searchable PDF
}
```

Working from the structure directly:

```swift
for page in result.pages {
    for block in page.blocks {
        switch block.kind {
        case .heading(let level): print(String(repeating: "#", count: level), block.text)
        case .paragraph:          print(block.text)
        case .list(let list):     print(list.items.map(\.text))
        case .table(let table):   print(table.rows)
        }
    }
}
```

Screenshots have no heading hierarchy — large text is a button label, not a heading — so turn the inference off:

```swift
var options = ReaderOptions()
options.detectHeadings = false
```

## Two things this library exists to encode

**`minimumTextHeightFraction = 0`.** Vision's default silently discards short text: a table cell containing `3` is never recognised, while `312` in the same cell at the same font size is. It survives every render resolution from 2x to 6x, and *which* cells vanish changes between runs — so it presents as flaky OCR rather than as a setting. Measured on a three-cell column: **1 of 3 recovered by default, 3 of 3 with it set**.

**Deduplication is geometric, not textual.** Vision reports list-item and table-cell text in the `paragraphs` array as well. A list item's string has the marker stripped (`Latency dropped…`) while the paragraph keeps it (`• Latency dropped…`), so comparing text silently fails and every bullet is emitted twice. Overlap of bounding boxes is what actually identifies the same ink.

## Known limitations

- **Merged numbered list items.** Vision sometimes folds one entry into the previous one — `"Re-run the audit in April 3. Publish the summary"` arrives as a single item. `ListMarkerSplitter` splits these back out on an embedded marker; bulleted lists are unaffected.
- **Heading levels are inferred, not reported.** Height clustering works well on documents and is meaningless on UI captures. Use `detectHeadings: false` for those.
- **Resolution matters more than quality.** Format, rotation, blur, noise and uneven lighting barely affect recognition; dropping below roughly 150 dpi equivalent starts losing short cells.
- **Office formats are not images** and do not go through Vision at all.

## Testing

```bash
swift test
```

## License

MIT

## Author

David Sherlock
