//
//  LineRecognizer.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation
import Vision

/// Recognises a page as lines of text, each with a confidence and a box.
///
/// `RecognizeTextRequest`, not the document request: it has a fast level and language
/// correction, and it reports a confidence per line — the document request reports structure
/// instead.
enum LineRecognizer {

    static func lines(in image: CGImage, options: ReaderOptions) async throws -> [RecognizedLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = options.fastRecognition ? .fast : .accurate
        request.usesLanguageCorrection = !options.fastRecognition

        // The same setting the document path depends on. Measured on the line path over the
        // one- and two-character cells of four rendered tables: 11 of 24 recovered by default,
        // 14 of 24 with it — every gain on the clean pages, none lost on the degraded ones.
        // Language correction made no difference either way.
        request.minimumTextHeightFraction = 0

        if !options.recognitionLanguages.isEmpty {
            request.recognitionLanguages = options.recognitionLanguages.map { Locale.Language(identifier: $0) }
        }
        if !options.customWords.isEmpty {
            request.customWords = options.customWords
        }

        let observations = try await request.perform(on: ImageEnhancer.prepared(image, options))
        return observations.compactMap { observation in
            guard let best = observation.topCandidates(1).first else { return nil }
            return RecognizedLine(
                text: best.string,
                confidence: Double(best.confidence),
                frame: observation.boundingBox.cgRect
            )
        }
    }
}
