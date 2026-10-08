//
//  BarcodeDetector.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation
import Vision

/// Finds the barcodes and QR codes on a page.
enum BarcodeDetector {

    /// Never enhanced: the contrast stretch that rescues faded text clips the quiet zone a
    /// scanner needs around a code.
    static func barcodes(in image: CGImage, page: Int) async throws -> [DetectedBarcode] {
        let observations = try await DetectBarcodesRequest().perform(on: image)
        return observations.compactMap { observation in
            guard let payload = observation.payloadString else { return nil }
            return DetectedBarcode(
                pageNumber: page,
                symbology: String(describing: observation.symbology),
                payload: payload,
                frame: observation.boundingBox.cgRect
            )
        }
    }
}
