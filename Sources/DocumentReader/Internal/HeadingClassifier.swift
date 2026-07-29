//
//  HeadingClassifier.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// Works out which paragraphs are headings, and at what level.
///
/// Vision has no concept of a heading level — `RecognizeDocumentsRequest` returns paragraphs,
/// and a heading is simply a paragraph set in larger type. The only signal available is the
/// height of each block's bounding box.
///
/// Fixed ratio thresholds do not survive contact with real pages. Measured on one test
/// document, body text sat at 0.0187 of page height and its subheadings at 0.0208 — a ratio of
/// 1.11, which a plausible-looking 1.15 cut missed entirely, while a page with a larger
/// heading font would sail past the same cut. So heights are **clustered** instead: whatever
/// the page's own body size turns out to be becomes the baseline, and distinct larger sizes
/// become levels in descending order.
enum HeadingClassifier {

    /// Assigns heading levels to paragraph blocks.
    ///
    /// - Parameters:
    ///   - blocks: Blocks in reading order.
    ///   - title: The recogniser's own title, promoted to level 1 when it matches a block.
    /// - Returns: The same blocks, with paragraphs reclassified as headings where warranted.
    static func apply(to blocks: [DocumentBlock], title: String?) -> [DocumentBlock] {
        let heights = blocks.compactMap { block -> CGFloat? in
            guard case .paragraph = block.kind else { return nil }
            return block.frame.height
        }
        guard heights.count > 1, let body = bodyHeight(from: heights) else { return blocks }

        // Sizes meaningfully larger than body text, largest first. 6% is enough to clear
        // measurement noise on the same font without discarding a genuine one-step heading.
        let headingSizes = cluster(heights.filter { $0 > body * minimumHeadingRatio })
            .sorted(by: >)

        let trimmedTitle = title?.trimmed

        return blocks.map { block in
            guard case .paragraph = block.kind else { return block }

            // The recogniser named this as the document title, so it is level 1 regardless of
            // how its height compares.
            if let trimmedTitle, !trimmedTitle.isEmpty, block.text == trimmedTitle {
                return DocumentBlock(kind: .heading(level: 1), text: block.text, frame: block.frame, words: block.words)
            }

            guard let index = headingSizes.firstIndex(where: {
                abs(block.frame.height - $0) <= $0 * clusterTolerance
            }) else {
                return block
            }

            // A title already occupies level 1, so everything else starts at 2.
            let base = (trimmedTitle?.isEmpty == false) ? 2 : 1
            let level = min(base + index, maximumLevel)
            return DocumentBlock(kind: .heading(level: level), text: block.text, frame: block.frame, words: block.words)
        }
    }

    // MARK: - Tuning

    /// How much taller than body text a block must be to count as a heading.
    private static let minimumHeadingRatio: CGFloat = 1.06

    /// How close two heights must be to count as the same size.
    private static let clusterTolerance: CGFloat = 0.08

    /// Markdown goes to six, but a page with more than three visible tiers is rare and the
    /// inference is not precise enough to justify claiming more.
    private static let maximumLevel = 3

    // MARK: - Measurement

    /// The page's body text height.
    ///
    /// The **most common** size, not the median. The assumption being made is that body text is
    /// whatever appears most on a page, and the median only approximates that while body text
    /// happens to dominate. It breaks on exactly the pages this library is for: a short page of
    /// six blocks, four of which are headings, puts the median *on a heading* — which then
    /// becomes the baseline, and every real heading at that size is classified as body.
    ///
    /// Counting clusters says what the median only assumes.
    private static func bodyHeight(from heights: [CGFloat]) -> CGFloat? {
        guard !heights.isEmpty else { return nil }

        var groups: [(height: CGFloat, count: Int)] = []
        for height in heights.sorted() {
            if let last = groups.last, abs(height - last.height) <= last.height * clusterTolerance {
                groups[groups.count - 1].count += 1
            } else {
                groups.append((height, 1))
            }
        }

        // Ties go to the smaller size: headings are the exception on a page, body is the rule,
        // so when two sizes are equally common the smaller is far more likely to be the body.
        return groups.max { a, b in
            a.count != b.count ? a.count < b.count : a.height > b.height
        }?.height
    }

    /// Groups near-identical heights into representative sizes.
    private static func cluster(_ heights: [CGFloat]) -> [CGFloat] {
        var clusters: [CGFloat] = []
        for height in heights.sorted() {
            if let last = clusters.last, abs(height - last) <= last * clusterTolerance {
                // Average into the existing cluster so it settles on the group's centre.
                clusters[clusters.count - 1] = (last + height) / 2
            } else {
                clusters.append(height)
            }
        }
        return clusters
    }
}
