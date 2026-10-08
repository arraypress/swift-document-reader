//
//  PDFProbe.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation
import PDFKit

/// Opens a file as a PDF only if it is one.
///
/// Handing PDFKit a PNG to find out logs "CoreGraphics PDF has logged an error" on stderr — once
/// per picture, so a folder of photographs fills a terminal with it. The header says what the
/// file is before PDFKit is asked: every PDF starts `%PDF`, whatever its name.
enum PDFProbe {

    static func document(at url: URL) -> PDFDocument? {
        guard isPDF(url) else { return nil }
        return PDFDocument(url: url)
    }

    static func isPDF(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let header = (try? handle.read(upToCount: 4)) ?? Data()
        return header == Data("%PDF".utf8)
    }
}
