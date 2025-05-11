//
//  BundleResourceProvider.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation
import Versioning

/// A protocol that defines common resource and metadata accessors for a `Bundle`.
///
/// Types conforming to this protocol provide closures that allow callers to access
/// bundle-related information such as resource URLs, identifiers, names, and version strings.
public protocol BundleResourceProvider: Sendable {

    /// A closure that returns the URL for a specified resource in the bundle.
    ///
    /// - Parameters:
    ///   - fileName: The name of the resource file (without extension).
    ///   - fileExtension: The file extension of the resource.
    /// - Returns: The URL of the resource.
    /// - Throws: An error if the resource could not be found.
    var urlForResource: @Sendable (_ fileName: String, _ fileExtension: String) throws -> URL { get }

    /// A closure that extracts the bundle's identifier string.
    ///
    /// - Returns: The bundle identifier.
    /// - Throws: An error if the identifier is not available.
    var extractIdentifier: @Sendable () throws -> String { get }

    /// A closure that extracts the bundle's display name.
    ///
    /// - Returns: The display name of the bundle.
    /// - Throws: An error if the name is not available.
    var extractName: @Sendable () throws -> String { get }

    /// A closure that extracts the short version string from the bundle
    /// and parses it into a `SemanticVersion` value.
    ///
    /// - Returns: The parsed semantic version.
    /// - Throws: An error if the version string is missing or invalid.
    var extractShortVersionString: @Sendable () throws -> SemanticVersion { get }
}
