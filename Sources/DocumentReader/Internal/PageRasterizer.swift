//
//  PageRasterizer.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation
import PDFKit

#if canImport(AppKit)
import AppKit
#endif

/// Turns PDF pages and image files into `CGImage`s for recognition.
enum PageRasterizer {

    /// Renders one PDF page.
    ///
    /// Drawn onto an explicit white background rather than a transparent one. A PDF page has no
    /// background of its own, and text on transparency recognises far worse than the same text
    /// on white — the contrast the recogniser depends on simply is not there.
    static func render(page: PDFPage, scale: CGFloat) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard width > 0, height > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        page.draw(with: .mediaBox, to: context)

        return context.makeImage()
    }

    /// Loads an image file.
    ///
    /// Format is irrelevant to recognition — PNG, JPEG, HEIC and TIFF all decode to the same
    /// pixels and measured identically — so anything ImageIO can open is accepted rather than
    /// gate-keeping on file extension.
    static func image(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
