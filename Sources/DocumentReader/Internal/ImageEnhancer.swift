//
//  ImageEnhancer.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import CoreImage
import Foundation

/// What an OCR pipeline does to a poor page first: greyscale, contrast, sharpen.
///
/// Applied only when ``ReaderOptions/enhance`` asks — see there for the measurements that keep
/// it off by default.
enum ImageEnhancer {

    /// One shared context: creating a `CIContext` per page is the expensive part.
    private static let context = CIContext()

    /// The enhanced image, or the original if the filters produced nothing.
    static func enhanced(_ image: CGImage) -> CGImage {
        let output = CIImage(cgImage: image)
            .applyingFilter("CIPhotoEffectMono")
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 2.4, kCIInputBrightnessKey: -0.10,
            ])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 2.0, kCIInputIntensityKey: 1.2,
            ])
        return context.createCGImage(output, from: output.extent) ?? image
    }

    /// The image to recognise, enhanced or not as the options say.
    static func prepared(_ image: CGImage, _ options: ReaderOptions) -> CGImage {
        options.enhance ? enhanced(image) : image
    }
}
