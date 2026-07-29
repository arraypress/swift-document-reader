//
//  DocumentReaderError.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why a read failed.
public enum DocumentReaderError: LocalizedError, Equatable {

    /// The file could not be opened, or is not a PDF or image.
    case unreadableFile(URL)

    /// A PDF opened but reported no pages.
    case emptyDocument(URL)

    /// A page could not be turned into an image for recognition.
    case renderFailed(page: Int)

    /// Vision returned nothing for a page.
    case recognitionFailed(page: Int)

    public var errorDescription: String? {
        switch self {
        case .unreadableFile(let url):
            return "\(url.lastPathComponent) could not be read as a PDF or image."
        case .emptyDocument(let url):
            return "\(url.lastPathComponent) contains no pages."
        case .renderFailed(let page):
            return "Page \(page) could not be rendered for recognition."
        case .recognitionFailed(let page):
            return "Nothing could be recognised on page \(page)."
        }
    }
}
