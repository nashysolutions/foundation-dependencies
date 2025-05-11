//
//  XcodeBundle.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation
import Versioning

/// A protocol that provides access to the `Bundle` associated with the conforming type.
///
/// This protocol is intended for types that provide resources from a specific Xcode bundle.
/// It also provides convenience methods for retrieving common bundle metadata.
public protocol XcodeBundle: AnyObject, BundleResourceProvider {
    
    /// The bundle associated with the conforming type.
    static var bundle: Bundle { get }
}

public extension XcodeBundle {
    
    /// The bundle associated with the current type, resolved using `Bundle(for:)`.
    static var bundle: Bundle {
        Bundle(for: Self.self)
    }
    
    /// Returns a closure that retrieves the URL for a specified resource in the bundle.
    ///
    /// - Returns: A closure that takes a file name and file extension and returns the corresponding resource URL.
    /// - Throws: `XcodeBundleError.resourceNotFound` if the resource could not be found.
    var urlForResource: @Sendable (_ fileName: String, _ fileExtension: String) throws -> URL {
        return { fileName, fileExtension in
            guard let url = Self.bundle.url(forResource: fileName, withExtension: fileExtension) else {
                throw XcodeBundleError.resourceNotFound(name: fileName, fileExtension: fileExtension)
            }
            return url
        }
    }
    
    /// Returns a closure that extracts the bundle identifier.
    ///
    /// - Returns: A closure that returns the bundle identifier as a `String`.
    /// - Throws: `XcodeBundleError.bundleIdentifierMissing` if the bundle identifier is not available.
    var extractIdentifier: @Sendable () throws -> String {
        return {
            guard let identifier = Self.bundle.bundleIdentifier else {
                throw XcodeBundleError.bundleIdentifierMissing
            }
            return identifier
        }
    }
    
    /// Returns a closure that extracts the bundle name from the `CFBundleName` key.
    ///
    /// - Returns: A closure that returns the bundle name.
    /// - Throws: `XcodeBundleError.bundleNameMissing` if the name could not be found.
    var extractName: @Sendable () throws -> String {
        return {
            guard let name = Self.bundle.object(forInfoDictionaryKey: "CFBundleName") as? String else {
                throw XcodeBundleError.bundleNameMissing
            }
            return name
        }
    }
    
    /// Returns a closure that extracts the short version string and parses it as a `SemanticVersion`.
    ///
    /// - Returns: A closure that returns the parsed `SemanticVersion`.
    /// - Throws:
    ///   - `XcodeBundleError.versionStringMissing` if the version string is not found.
    ///   - `XcodeBundleError.invalidVersionFormat` if the string is not a valid semantic version.
    var extractShortVersionString: @Sendable () throws -> SemanticVersion {
        return {
            guard let value = Self.bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
                throw XcodeBundleError.versionStringMissing
            }
            guard let version = SemanticVersion(value) else {
                throw XcodeBundleError.invalidVersionFormat(value)
            }
            return version
        }
    }

    /// Returns a closure that extracts the build number and converts it to a `Double`.
    ///
    /// - Returns: A closure that returns the build number.
    /// - Throws: `XcodeBundleError.buildNumberMissing` if the value is not present or not convertible to a `Double`.
    var extractBuildNumber: @Sendable () throws -> Double {
        return {
            guard
                let value = Self.bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                let buildNumber = Double(value)
            else {
                throw XcodeBundleError.buildNumberMissing
            }
            return buildNumber
        }
    }
}
