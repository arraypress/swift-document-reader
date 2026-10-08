//
//  DetectedBarcode.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// A barcode or QR code found on a page.
///
/// ```swift
/// for code in try await DocumentReader.barcodes(contentsOf: url) {
///     print(code.symbology, code.payload)
/// }
/// ```
public struct DetectedBarcode: Sendable, Codable, Equatable {

    /// 1-based page number the code was on.
    public let pageNumber: Int

    /// The symbology as Vision names it — `QR`, `EAN13`, `Code128`…
    public let symbology: String

    /// The decoded payload.
    public let payload: String

    /// Where the code sat, normalised, origin bottom left.
    public let frame: CGRect

    public init(pageNumber: Int, symbology: String, payload: String, frame: CGRect) {
        self.pageNumber = pageNumber
        self.symbology = symbology
        self.payload = payload
        self.frame = frame
    }
}
