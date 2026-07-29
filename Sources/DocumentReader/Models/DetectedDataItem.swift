//
//  DetectedDataItem.swift
//  DocumentReader
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A piece of structured data Vision found inside recognised text.
///
/// The recogniser identifies these for free while it reads the page — URLs, email addresses,
/// phone numbers, postal addresses, monetary amounts, flight numbers, tracking numbers,
/// calendar events and measurements. Extracting them afterwards with regular expressions is
/// both slower and worse.
///
/// ```swift
/// for item in result.detectedData {
///     print("\(item.kind): \(item.value)")
/// }
/// // email: david@example.com
/// // phoneNumber: 555-0142
/// // calendarEvent: end: 2026-04-14
/// ```
public struct DetectedDataItem: Sendable, Codable, Equatable {

    /// The category of detected data.
    public enum Kind: String, Sendable, Codable {

        /// A URL or web link.
        case url

        /// An email address.
        case email

        /// A phone number.
        case phoneNumber

        /// A postal/mailing address.
        case postalAddress

        /// A monetary amount with currency.
        case moneyAmount

        /// An airline flight number.
        case flightNumber

        /// A shipment tracking number.
        case shipmentTracking

        /// A calendar event with date/time.
        case calendarEvent

        /// A physical measurement.
        case measurement

        /// A payment identifier.
        case paymentIdentifier

        /// An unrecognised data type.
        case unknown
    }

    /// The category of this item.
    public let kind: Kind

    /// A readable rendering of the value.
    public let value: String

    public init(kind: Kind, value: String) {
        self.kind = kind
        self.value = value
    }
}
