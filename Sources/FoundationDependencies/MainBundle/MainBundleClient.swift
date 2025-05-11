//
//  MainBundleClient.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation
import Dependencies
import Versioning

public struct MainBundleClient: BundleResourceProvider, Sendable {
    
    public var urlForResource: @Sendable (_ fileName: String, _ fileExtension: String) throws -> URL
    public var extractIdentifier: @Sendable () throws -> String
    public var extractName: @Sendable () throws -> String
    public var extractShortVersionString: @Sendable () throws -> SemanticVersion
    public var extractBuildNumber: @Sendable () throws -> Double
    
    public init(
        urlForResource: @Sendable @escaping (_: String, _: String) throws -> URL,
        extractIdentifier: @Sendable @escaping () throws -> String,
        extractName: @Sendable @escaping () throws -> String,
        extractShortVersionString: @Sendable @escaping () throws -> SemanticVersion,
        extractBuildNumber: @Sendable @escaping () throws -> Double
    ) {
        self.urlForResource = urlForResource
        self.extractIdentifier = extractIdentifier
        self.extractName = extractName
        self.extractShortVersionString = extractShortVersionString
        self.extractBuildNumber = extractBuildNumber
    }
}

public enum MainBundleClientKey: TestDependencyKey {
    
   public static let testValue: MainBundleClient = {
        return MainBundleClient(urlForResource: { name, ext in
            throw XcodeBundleError.resourceNotFound(name: name, fileExtension: ext)
        }, extractIdentifier: {
            throw XcodeBundleError.bundleIdentifierMissing
        }, extractName: {
            throw XcodeBundleError.bundleNameMissing
        }, extractShortVersionString: {
            throw XcodeBundleError.shortVersionStringMissing
        }, extractBuildNumber: {
            throw XcodeBundleError.buildNumberMissing
        })
    }()
}

public extension DependencyValues {
    
    var mainBundleClient: MainBundleClient {
        get { self[MainBundleClientKey.self] }
        set { self[MainBundleClientKey.self] = newValue }
    }
}
