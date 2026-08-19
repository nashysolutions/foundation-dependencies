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

/// Covers the seam between the log client and the main bundle client.
///
/// The logger's subsystem is the bundle identifier, and the client that supplies it is read
/// when a logger is created rather than when the log client is registered. That is what lets
/// a caller install a replacement client for the duration of a scope and have the loggers
/// built inside that scope use it. `os.Logger` does not expose the subsystem it was given,
/// so the installed client recording that it was asked is the observable end of that path.
///
/// What this cannot catch is the compile-time reason the initialiser reads through the key
/// rather than through the key path. The two forms resolve the same value, so swapping one
/// for the other leaves every case here green. A strict concurrency build is the guard for
/// that, not a test.
@Suite("Log client dependency resolution")
struct LogClientDependencyResolutionTests {

    @Test("Creating a logger reads the main bundle client that is installed at the time")
    func creatingALoggerReadsTheInstalledMainBundleClient() {
        let identifier = "com.example.installed-for-this-case"
        let requests = IdentifierRequests()
        var logging: LogClient?
        withDependencies {
            $0.mainBundleClient = bundleClient(reporting: identifier, recordingInto: requests)
            // Taken here rather than with `@Dependency(\.loggerClient)` inside the operation
            // below, because that key path would draw the same strict concurrency warning in
            // this target that the code under test was changed to avoid. The log client is a
            // fixed value either way; what has to happen inside the operation is the call.
            logging = $0.loggerClient
        } operation: {
            _ = logging?.logger("Category")
        }
        #expect(requests.recorded == [identifier])
    }
}

/// The bundle identifiers a client was asked for, in the order it was asked.
///
/// The client's endpoints are synchronous and are required to be safe to call from any
/// thread, which rules out an actor here. Every access to the stored array goes through the
/// lock, which is the whole of the invariant behind the unchecked conformance.
private final class IdentifierRequests: @unchecked Sendable {

    private let lock = NSLock()
    private var values: [String] = []

    func record(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        values.append(value)
    }

    var recorded: [String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

/// A main bundle client that answers `extractIdentifier` with the given identifier and
/// records each time it is asked for one.
///
/// The four other endpoints that can throw do throw, so a case that reaches one of them
/// fails rather than reading a value this helper invented. `imageAsset` and `colorAsset`
/// cannot throw, so they have no way to fail a case and instead hand back an asset named
/// after whatever was asked for. No case here calls them. One that did would be reading a
/// name this helper made up, and would need to assert the call happened rather than rely
/// on the returned value.
private func bundleClient(
    reporting identifier: String,
    recordingInto requests: IdentifierRequests
) -> MainBundleClient {
    MainBundleClient(
        urlForResource: { name, fileExtension in
            throw XcodeBundleError.resourceNotFound(name: name + fileExtension)
        },
        extractIdentifier: {
            requests.record(identifier)
            return identifier
        },
        extractName: { throw XcodeBundleError.bundleNameMissing },
        extractShortVersionString: { throw XcodeBundleError.shortVersionStringMissing },
        extractBuildNumber: { throw XcodeBundleError.buildNumberMissing },
        imageAsset: { ImageAsset(name: $0, bundle: .main) },
        colorAsset: { ColorAsset(name: $0, bundle: .main) }
    )
}
