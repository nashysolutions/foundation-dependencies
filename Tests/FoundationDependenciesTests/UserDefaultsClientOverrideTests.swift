//
//  UserDefaultsClientOverrideTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 27/08/2026.
//

import Foundation
import Testing
import Dependencies
import FoundationDependencies

/// The two capabilities the closure-struct interface exists to provide.
///
/// Both were promised by the redesign rather than measured by it, and neither is
/// exercised anywhere else in this target: the contract suite runs whole stores, so a
/// client whose endpoints could not be replaced one at a time, or whose unimplemented
/// default reported nothing, would pass every case in it.
@Suite("Client overrides and the unimplemented default")
struct UserDefaultsClientOverrideTests {

    /// Replacing one endpoint must leave the other fourteen alone.
    ///
    /// This is the whole point of the reshape. Under the previous interface every
    /// operation was a get-only protocol requirement, so stubbing one meant building a
    /// client with all fifteen closures written out by hand.
    @Test("Replacing one endpoint leaves the rest routed to the store")
    func replacingOneEndpointLeavesTheRest() {
        let store = UserDefaultsTestStore()
        store.setInt(7, forKey: "key")

        var client = UserDefaultsClient(store)
        client.bool = { _ in true }

        #expect(client.bool(forKey: "key") == true, "The replaced endpoint did not take.")
        #expect(client.int(forKey: "key") == 7, "An untouched endpoint stopped reaching the store.")
    }

    /// The same thing through `withDependencies`, which is how a consumer reaches it.
    ///
    /// Asserted separately from the case above because the assignment goes through
    /// `DependencyValues` rather than a local variable, and a client that could be
    /// mutated locally but not in a dependency override would still fail the reader.
    @Test("One endpoint can be replaced through withDependencies")
    func oneEndpointCanBeReplacedThroughWithDependencies() {
        withDependencies {
            $0.userDefaultsClient = UserDefaultsClient(UserDefaultsTestStore())
            $0.userDefaultsClient.string = { _ in "stubbed" }
        } operation: {
            @Dependency(UserDefaultsClient.self) var client

            client.setInt(7, forKey: "key")

            #expect(client.string(forKey: "key") == "stubbed")
            #expect(client.int(forKey: "key") == 7)
        }
    }

    /// `UserDefaultsClient()` is the unimplemented client, and calling an endpoint on
    /// it must report.
    ///
    /// The point of the type is that a test which reaches an endpoint it did not think
    /// about fails rather than reads a plausible default, so an endpoint that silently
    /// returned `false` would be worse than useless. `withKnownIssue` is what turns
    /// "an issue was reported" into a passing assertion; without the report, the body
    /// records nothing and the case fails.
    ///
    /// ``UserDefaultsClient/bool`` and ``UserDefaultsClient/string`` are asserted
    /// because they report by different routes, and only one of the two comes free.
    /// `string` returns an optional, so `@DependencyClient` generates its reporting
    /// default; `bool` cannot have one generated and carries a written-out default in
    /// source, which supersedes the macro's. Written the obvious way, as
    /// `= { _ in false }`, `bool` reported nothing at all. This case is what stops that
    /// silence coming back.
    @Test(
        "An endpoint on the unimplemented client reports an issue",
        arguments: [UnimplementedEndpoint.bool, .string]
    )
    func unimplementedEndpointReportsAnIssue(_ endpoint: UnimplementedEndpoint) {
        withKnownIssue {
            endpoint.call(on: UserDefaultsClient())
        }
    }

    /// The control for the case above.
    ///
    /// Without it, a `withKnownIssue` that passed for some unrelated reason would look
    /// the same as the unimplemented default reporting correctly. A client built over a
    /// real store must report nothing through the same endpoint.
    @Test("The same endpoint on a real store reports nothing")
    func anImplementedEndpointReportsNothing() {
        let client = UserDefaultsClient(UserDefaultsTestStore())

        #expect(client.bool(forKey: "key") == false)
    }
}

/// The two endpoints whose unimplemented defaults are produced differently.
///
/// A pair rather than all fifteen, because the two routes are what differ: every other
/// endpoint reaches its default the same way as one of these.
enum UnimplementedEndpoint: String, CaseIterable, Sendable, CustomTestStringConvertible {

    /// Reports through a default written out in source.
    case bool

    /// Reports through the default `@DependencyClient` generates.
    case string

    var testDescription: String {
        rawValue
    }

    func call(on client: UserDefaultsClient) {
        switch self {
        case .bool:
            _ = client.bool(forKey: "key")
        case .string:
            _ = client.string(forKey: "key")
        }
    }
}
