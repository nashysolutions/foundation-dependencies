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

    /// The `Codable` methods are not endpoints, and replacing the two endpoints they
    /// are built on is what stubs them.
    ///
    /// This is the property that makes them methods rather than a missing feature. A
    /// generic endpoint is impossible — a stored closure cannot be generic — so if the
    /// `Codable` path did not route through `data` and `setData`, there would be a
    /// third thing a test had to know to stub, and no way to stub it.
    @Test("Replacing the data endpoints replaces the Codable path")
    func replacingDataEndpointsReplacesTheCodablePath() throws {
        var client = UserDefaultsClient(UserDefaultsTestStore())
        client.data = { _ in Data("\"stubbed\"".utf8) }

        #expect(try client.decode(String.self, forKey: "never-written") == "stubbed")
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

    /// `UserDefaultsClient()` is the unimplemented client, and calling any endpoint on
    /// it must report.
    ///
    /// The point of the type is that a test which reaches an endpoint it did not think
    /// about fails rather than reads a plausible default, so an endpoint that silently
    /// returned `false` would be worse than useless. `withKnownIssue` is what turns
    /// "an issue was reported" into a passing assertion; without the report, the body
    /// records nothing and the case fails.
    ///
    /// Every endpoint is a row rather than a representative pair, and the widening is
    /// the point. Two endpoints reach their default by different routes, and only one
    /// of the two comes free: an endpoint returning an optional or `Void` gets a
    /// reporting default from `@DependencyClient`, while one returning a non-optional
    /// cannot have one generated, because the macro has nothing to return after
    /// reporting, and has to carry a default written out in source. Written the obvious
    /// way, as `= { _ in false }`, such an endpoint reported nothing at all, and a
    /// source default supersedes the generated one, so the silence was total and
    /// invisible.
    ///
    /// ``UserDefaultsClient/contains`` is the only endpoint in that position today,
    /// and it used to be three: ``UserDefaultsClient/bool``,
    /// ``UserDefaultsClient/int`` and ``UserDefaultsClient/double`` returned
    /// non-optionals and carried the same duplication until the read surface became
    /// optional. Listing every endpoint rather than one from each route is what stops
    /// this case from going quiet the next time an endpoint moves between them, or a
    /// new one arrives in the position that has to be written out by hand.
    @Test(
        "Every endpoint on the unimplemented client reports an issue",
        arguments: UnimplementedEndpoint.all
    )
    func unimplementedEndpointReportsAnIssue(_ endpoint: UnimplementedEndpoint) {
        withKnownIssue {
            endpoint.call(UserDefaultsClient())
        }
    }

    /// The control for the case above.
    ///
    /// Without it, a `withKnownIssue` that passed for some unrelated reason would look
    /// the same as the unimplemented default reporting correctly. A client built over a
    /// real store must report nothing through the same endpoints.
    @Test(
        "The same endpoint on a real store reports nothing",
        arguments: UnimplementedEndpoint.all
    )
    func anImplementedEndpointReportsNothing(_ endpoint: UnimplementedEndpoint) {
        endpoint.call(UserDefaultsClient(UserDefaultsTestStore()))
    }
}

/// Every endpoint on the client, so that the unimplemented-default case covers the
/// whole surface rather than a sample of it.
///
/// A table of closures rather than an enum with a `switch`, for two reasons. Adding an
/// endpoint is one line here instead of three in two places, which is what decides
/// whether the next person adds it at all. And an endpoint that is renamed or retired
/// stops compiling in the row that calls it, naming that row, rather than in a
/// nineteen-case `switch` that has to be read to find out which arm broke.
///
/// The one gap left is an endpoint added to the client with no row added here. Nothing
/// makes that a compiler error. It is a smaller gap than the one this replaced, which
/// covered two endpoints of fifteen.
struct UnimplementedEndpoint: Sendable, CustomTestStringConvertible {

    /// The endpoint's name, which is what a failing row is reported as.
    let name: String

    /// Calls the endpoint, discarding whatever it returns.
    let call: @Sendable (UserDefaultsClient) -> Void

    var testDescription: String {
        name
    }

    private init(_ name: String, _ call: @escaping @Sendable (UserDefaultsClient) -> Void) {
        self.name = name
        self.call = call
    }

    static let all: [UnimplementedEndpoint] = [
        UnimplementedEndpoint("bool") { _ = $0.bool(forKey: "key") },
        UnimplementedEndpoint("int") { _ = $0.int(forKey: "key") },
        UnimplementedEndpoint("double") { _ = $0.double(forKey: "key") },
        UnimplementedEndpoint("string") { _ = $0.string(forKey: "key") },
        UnimplementedEndpoint("stringArray") { _ = $0.stringArray(forKey: "key") },
        UnimplementedEndpoint("date") { _ = $0.date(forKey: "key") },
        UnimplementedEndpoint("data") { _ = $0.data(forKey: "key") },
        UnimplementedEndpoint("url") { _ = $0.url(forKey: "key") },
        UnimplementedEndpoint("contains") { _ = $0.contains(key: "key") },
        UnimplementedEndpoint("setBool") { $0.setBool(true, forKey: "key") },
        UnimplementedEndpoint("setInt") { $0.setInt(42, forKey: "key") },
        UnimplementedEndpoint("setDouble") { $0.setDouble(3.5, forKey: "key") },
        UnimplementedEndpoint("setString") { $0.setString("abc", forKey: "key") },
        UnimplementedEndpoint("setStringArray") { $0.setStringArray(["a"], forKey: "key") },
        UnimplementedEndpoint("setDate") { $0.setDate(Date(timeIntervalSince1970: 0), forKey: "key") },
        UnimplementedEndpoint("setData") { $0.setData(Data([0x01]), forKey: "key") },
        UnimplementedEndpoint("setURL") { $0.setURL(URL(fileURLWithPath: "/tmp"), forKey: "key") },
        UnimplementedEndpoint("setPropertyList") { $0.setPropertyList("abc", forKey: "key") },
        UnimplementedEndpoint("removeValue") { $0.removeValue(forKey: "key") }
    ]
}
