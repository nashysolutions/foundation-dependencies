//
//  XcodeBundleError.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// An error type representing possible failures when accessing resources or metadata from a bundle.
public enum XcodeBundleError: LocalizedError {
    
    /// Indicates that a resource with the specified name and extension could not be found in the bundle.
    ///
    /// - Parameters:
    ///   - name: The name of the missing resource.
    ///   - fileExtension: The file extension of the missing resource.
    case resourceNotFound(name: String, fileExtension: String)
    
    /// Indicates that the bundle identifier is missing.
    case bundleIdentifierMissing
    
    /// Indicates that the bundle name is missing (`CFBundleName` key is not present).
    case bundleNameMissing
    
    /// Indicates that the short version string is missing (`CFBundleShortVersionString` key is not present).
    case shortVersionStringMissing
    
    /// Indicates that the version string is missing (`CFBundleShortVersionString` key is not present).
    ///
    /// This may be used interchangeably with `.shortVersionStringMissing` in your logic.
    case versionStringMissing
    
    /// Indicates that the build number is missing or invalid (`CFBundleVersion` key is not present or not a valid number).
    case buildNumberMissing
    
    /// Indicates that the version string could not be parsed into a valid `SemanticVersion`.
    ///
    /// - Parameter version: The invalid version string.
    case invalidVersionFormat(String)
    
    /// A human-readable description of the error.
    public var errorDescription: String? {
        switch self {
        case let .resourceNotFound(name, fileExtension):
            return "Resource \(name).\(fileExtension) not found in bundle."
        case .bundleIdentifierMissing:
            return "Bundle identifier is missing."
        case .bundleNameMissing:
            return "Bundle name is missing."
        case .shortVersionStringMissing:
            return "CFBundleShortVersionString is missing from the bundle."
        case .versionStringMissing:
            return "CFBundleShortVersionString is missing from the bundle."
        case .buildNumberMissing:
            return "CFBundleVersion is missing from the bundle."
        case .invalidVersionFormat(let version):
            return "The version string '\(version)' is not in a valid format."
        }
    }
}
