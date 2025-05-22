//
//  MainBundleClient.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation
import Dependencies
import Versioning

/// A resource provider for accessing values from the main app bundle.
public struct MainBundleClient: BundleResourceProvider, Sendable {
    
    /// Returns the URL for a resource in the main bundle.
    ///
    /// - Parameters:
    ///   - fileName: The name of the resource file (without extension).
    ///   - fileExtension: The file extension (e.g. `"txt"`, `"json"`).
    /// - Throws: An error if the resource cannot be found or accessed.
    /// - Returns: The URL for the requested resource.
    public var urlForResource: @Sendable (_ fileName: String, _ fileExtension: String) throws -> URL
    
    /// Extracts the bundle identifier from the main bundle.
    ///
    /// - Throws: An error if the identifier cannot be retrieved.
    /// - Returns: The bundle identifier string (e.g. `"com.example.MyApp"`).
    public var extractIdentifier: @Sendable () throws -> String

    /// Extracts the display name of the main bundle.
    ///
    /// - Throws: An error if the name cannot be retrieved.
    /// - Returns: The display name of the bundle (e.g. `"MyApp"`).
    public var extractName: @Sendable () throws -> String

    /// Extracts the short version string from the main bundle.
    ///
    /// - Throws: An error if the version string is missing or malformed.
    /// - Returns: A semantic version representing `CFBundleShortVersionString`.
    public var extractShortVersionString: @Sendable () throws -> SemanticVersion

    /// Extracts the build number from the main bundle.
    ///
    /// - Throws: An error if the build number is missing or not convertible to a `Double`.
    /// - Returns: The build number as a `Double`, typically from `CFBundleVersion`.
    public var extractBuildNumber: @Sendable () throws -> Double

    /// Returns an `ImageAsset` for the given name using the main bundle.
    ///
    /// - Parameter name: The name of the image asset.
    /// - Throws: An error if the asset cannot be resolved.
    /// - Returns: A type-safe wrapper for the image asset.
    public var imageAsset: @Sendable (_ name: String) throws -> ImageAsset

    /// Returns a `ColorAsset` for the given name using the main bundle.
    ///
    /// - Parameter name: The name of the colour asset.
    /// - Throws: An error if the asset cannot be resolved.
    /// - Returns: A type-safe wrapper for the colour asset.
    public var colorAsset: @Sendable (_ name: String) throws -> ColorAsset

    /// Creates a new `MainBundleClient` with the specified resource access closures.
    ///
    /// - Parameters:
    ///   - urlForResource: A closure that returns a URL for a given file name and extension.
    ///   - extractIdentifier: A closure that returns the bundle identifier.
    ///   - extractName: A closure that returns the bundle name.
    ///   - extractShortVersionString: A closure that returns the short version string.
    ///   - extractBuildNumber: A closure that returns the build number as a `Double`.
    ///   - imageAsset: A closure that returns an `ImageAsset` for a given name.
    ///   - colorAsset: A closure that returns a `ColorAsset` for a given name.
    public init(
        urlForResource: @Sendable @escaping (_: String, _: String) throws -> URL,
        extractIdentifier: @Sendable @escaping () throws -> String,
        extractName: @Sendable @escaping () throws -> String,
        extractShortVersionString: @Sendable @escaping () throws -> SemanticVersion,
        extractBuildNumber: @Sendable @escaping () throws -> Double,
        imageAsset: @Sendable @escaping (_: String) throws -> ImageAsset,
        colorAsset: @Sendable @escaping (_: String) throws -> ColorAsset
    ) {
        self.urlForResource = urlForResource
        self.extractIdentifier = extractIdentifier
        self.extractName = extractName
        self.extractShortVersionString = extractShortVersionString
        self.extractBuildNumber = extractBuildNumber
        self.imageAsset = imageAsset
        self.colorAsset = colorAsset
    }
}

public enum MainBundleClientKey: TestDependencyKey {
    
   public static let testValue: MainBundleClient = {
        return MainBundleClient(urlForResource: { name, ext in
            throw XcodeBundleError.resourceNotFound(name: name + ext)
        }, extractIdentifier: {
            throw XcodeBundleError.bundleIdentifierMissing
        }, extractName: {
            throw XcodeBundleError.bundleNameMissing
        }, extractShortVersionString: {
            throw XcodeBundleError.shortVersionStringMissing
        }, extractBuildNumber: {
            throw XcodeBundleError.buildNumberMissing
        }, imageAsset: { name in
            throw XcodeBundleError.resourceNotFound(name: name)
        }, colorAsset: { name in
            throw XcodeBundleError.resourceNotFound(name: name)
        })
    }()
}

public extension DependencyValues {
    
    var mainBundleClient: MainBundleClient {
        get { self[MainBundleClientKey.self] }
        set { self[MainBundleClientKey.self] = newValue }
    }
}
