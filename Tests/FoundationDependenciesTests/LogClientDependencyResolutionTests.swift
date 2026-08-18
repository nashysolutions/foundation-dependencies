//
//  LogClientDependencyResolutionTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import Dependencies
import FoundationDependencies

/// The Log module reads the main bundle client from its dependency key,
/// `MainBundleClientKey.self`, rather than from the `\.mainBundleClient` key path, because
/// `@Dependency` does not accept a key path written in source under strict concurrency in
/// the Swift 5 language mode.
///
/// That swap is only safe while both routes reach the same stored value. Callers install a
/// replacement client by assigning to the property, so if the two routes ever stopped
/// agreeing the logger would carry on using the default client while the caller believed it
/// had been replaced, and nothing would fail. This states the equivalence as an assertion
/// instead of leaving it as an assumption inside one initialiser.
@Test("A client installed through the property is read back through the key")
func clientInstalledThroughPropertyIsReadBackThroughKey() throws {
    let identifier = "com.example.installed-through-the-property"
    let resolvedIdentifier = try withDependencies {
        $0.mainBundleClient = bundleClient(reportingIdentifier: identifier)
    } operation: {
        @Dependency(MainBundleClientKey.self) var mainBundleClient
        return try mainBundleClient.extractIdentifier()
    }
    #expect(resolvedIdentifier == identifier)
}

/// A main bundle client that answers `extractIdentifier` with the given string.
///
/// Every other endpoint throws, matching the default test client, so a case that reaches one
/// of them fails rather than reading a value this helper invented.
private func bundleClient(reportingIdentifier identifier: String) -> MainBundleClient {
    MainBundleClient(
        urlForResource: { name, fileExtension in
            throw XcodeBundleError.resourceNotFound(name: name + fileExtension)
        },
        extractIdentifier: { identifier },
        extractName: { throw XcodeBundleError.bundleNameMissing },
        extractShortVersionString: { throw XcodeBundleError.shortVersionStringMissing },
        extractBuildNumber: { throw XcodeBundleError.buildNumberMissing },
        imageAsset: { ImageAsset(name: $0, bundle: .main) },
        colorAsset: { ColorAsset(name: $0, bundle: .main) }
    )
}
