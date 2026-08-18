//
//  UserDefaultsLiveStoreSuiteNameTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// How `UserDefaultsLiveStore` is reached, and what happens to a suite name Foundation
/// will not give out.
///
/// These cases are live-only rather than part of the two-store contract: the in-memory
/// store has no suite and no way to be misconfigured, so there is nothing to hold it to
/// here.
@Suite("Live store suite names")
@MainActor
struct UserDefaultsLiveStoreSuiteNameTests {

    @Test("A usable suite name produces a store")
    func aUsableSuiteNameProducesAStore() {
        withScratchSuite { suiteName in
            #expect(UserDefaultsLiveStore(suiteName: suiteName) != nil)
        }
    }

    /// The initialiser fails rather than handing back a store whose every read is
    /// empty and every write is discarded. This is the case the failable initialiser
    /// exists for.
    ///
    /// Foundation refuses two names. This is the one a test can reach: the other is the
    /// process's own bundle identifier, and under `swift test` there is no main bundle
    /// identifier to pass, so that half cannot be exercised from here. It is the same
    /// rejection inside Foundation either way.
    @Test("The global domain is refused")
    func theGlobalDomainIsRefused() {
        #expect(UserDefaultsLiveStore(suiteName: UserDefaults.globalDomain) == nil)
    }

    /// `standard` is the only route to the app's own defaults, since no suite name
    /// reaches them.
    ///
    /// Deliberately a read and never a write: this is the real defaults of whatever
    /// process is running the suite, and a case that wrote to it would leave state
    /// behind on the machine. Reading a key that has never existed is enough to show
    /// the store is wired to a live domain and answering.
    @Test("standard is reachable and answers")
    func standardIsReachable() {
        let neverWritten = "foundation-dependencies.never-written.\(UUID().uuidString)"

        #expect(UserDefaultsLiveStore.standard.string(neverWritten) == nil)
    }

    /// Two stores over the same suite name see each other's writes, which is what makes
    /// a shared app group container work at all.
    @Test("Two stores over one suite share their contents")
    func twoStoresOverOneSuiteShareContents() throws {
        try withScratchSuite { suiteName in
            let writer = try #require(UserDefaultsLiveStore(suiteName: suiteName))
            let reader = try #require(UserDefaultsLiveStore(suiteName: suiteName))

            writer.setInt(42, "key")

            #expect(reader.int("key") == 42)
        }
    }

    /// The teardown every live contract case relies on. If it did not work, cases would
    /// leak state into each other through the shared suite and the failure would look
    /// like a store bug.
    @Test("Removing the persistent domain empties the suite")
    func removingThePersistentDomainEmptiesTheSuite() throws {
        try withScratchSuite { suiteName in
            let store = try #require(UserDefaultsLiveStore(suiteName: suiteName))
            store.setInt(42, "key")
            #expect(store.int("key") == 42)

            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)

            let reopened = try #require(UserDefaultsLiveStore(suiteName: suiteName))
            expectAbsent(reopened, key: "key")
        }
    }
}
