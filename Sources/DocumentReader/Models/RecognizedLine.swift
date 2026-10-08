//
//  RecognizedLine.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// One line of recognised text, with how sure the recogniser was and where it sat.
///
/// ```swift
/// for page in try await DocumentReader.lines(contentsOf: url) {
///     for line in page.lines where line.frame.minY < 0.2 {
///         print(line.text)   // the bottom fifth of the page — where totals live
///     }
/// }
/// ```
public struct RecognizedLine: Sendable, Codable, Equatable {

    /// The text of the line.
    public let text: String

    /// The recogniser's confidence, 0 to 1.
    ///
    /// A floor on how much to worry, not a measure of accuracy: it saturates at 1.0 long before
    /// the error rate does — a fax-quality scan came back at 1.000 with a 1% character error.
    public let confidence: Double

    /// Where the line sat, normalised to the page with the origin at the **bottom left** —
    /// Vision's own convention, kept rather than flipped so the numbers match anything else
    /// reading the same page.
    public let frame: CGRect

    public init(text: String, confidence: Double, frame: CGRect) {
        self.text = text
        self.confidence = confidence
        self.frame = frame
    }
}
