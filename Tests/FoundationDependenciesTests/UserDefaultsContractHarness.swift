//
//  UserDefaultsContractHarness.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// Which implementation of `UserDefaultsStoreProtocol` a contract case runs against.
///
/// Every assertion in this target is written once and run against both conformers.
/// That is what makes the test double's fidelity a checked fact rather than a claim
/// in a doc comment: a divergence fails on the day it appears, instead of on the day
/// a consumer's passing test turns out to have been passing against behaviour
/// production does not have.
enum StoreKind: String, CaseIterable, Sendable, CustomTestStringConvertible {

    /// `UserDefaultsLiveStore`, backed by the shared scratch suite, which is emptied
    /// before and after the case.
    case live

    /// `UserDefaultsTestStore`, backed by its own in-memory dictionary.
    case testDouble

    var testDescription: String {
        rawValue
    }
}

/// The one suite every live case runs in.
///
/// It is a single fixed name rather than a fresh one per case, and that is deliberate.
/// macOS persists every suite domain it is ever shown: a suite per case left hundreds
/// of empty property lists in the preferences folder, one per case per run, growing on
/// every later run. Deleting the files does not fix it, because `cfprefsd` writes them
/// back after the test process has exited, so a check run straight after `swift test`
/// reports a clean folder and is simply measuring too early. One name means one file.
private let scratchSuiteName = "foundation-dependencies.contract"

/// How many live cases are currently inside the shared scratch suite.
///
/// Sharing one suite is only safe while no two live cases are in it at once. That
/// holds today because every live case is a synchronous body inside a `@MainActor`
/// test, so a case holds the main actor from the moment it takes the suite until it
/// gives it back, and Swift Testing cannot start another one in between.
///
/// That is a property of how these cases are written, not something the type system
/// enforces, so it is checked rather than assumed. Adding an `await` inside
/// `withScratchSuite` or inside a live case body would break it, and this counter is
/// what turns that into a clear failure naming the cause instead of a rare flake in
/// whichever case happened to lose the race.
///
/// The `@MainActor` annotations in this file and on the live suites are there for that
/// reason and no other. The store endpoints used to require the main actor, so the
/// annotations looked like something the compiler was asking for and the serialisation
/// came free; the endpoints are nonisolated now, and nothing but this counter would
/// notice if they were removed as leftovers.
@MainActor
private var liveCasesInScratchSuite = 0

/// Runs `body` against a store of the given kind, created fresh for this case.
///
/// The live kind gets the shared scratch suite, emptied on the way in as well as on
/// the way out. Emptying on the way in matters: it means a case cannot inherit state
/// from an earlier case that failed part way through, or from an interrupted run of
/// the whole target.
///
/// The initialiser is failable, so a name Foundation refuses would otherwise show up
/// as every read returning a default. `#require` turns that into one clear failure at
/// the point the store could not be made.
@MainActor
func withStore(
    _ kind: StoreKind,
    _ body: (any UserDefaultsStoreProtocol) throws -> Void
) throws {
    switch kind {
    case .testDouble:
        try body(UserDefaultsTestStore())
    case .live:
        try withScratchSuite { suiteName in
            let store = try #require(
                UserDefaultsLiveStore(suiteName: suiteName),
                "Foundation refused the scratch suite name \(suiteName)"
            )
            try body(store)
        }
    }
}

/// Reserves the shared scratch suite for the duration of `body`, emptied before and
/// after.
///
/// Used directly by the cases that need the suite name itself rather than a store
/// built over it.
@MainActor
func withScratchSuite(_ body: (String) throws -> Void) rethrows {
    liveCasesInScratchSuite += 1
    defer { liveCasesInScratchSuite -= 1 }

    #expect(
        liveCasesInScratchSuite == 1,
        """
        Two live cases were inside the shared scratch suite at the same time, so one \
        was reading and writing keys the other owned. They share one suite by design; \
        see the note on liveCasesInScratchSuite for why, and for the rule that keeps \
        them from overlapping.
        """
    )

    emptyScratchSuite()
    defer { emptyScratchSuite() }

    try body(scratchSuiteName)
}

/// Empties the shared scratch suite, leaving the key set as it was before any case
/// ran.
private func emptyScratchSuite() {
    UserDefaults(suiteName: scratchSuiteName)?
        .removePersistentDomain(forName: scratchSuiteName)
}

/// Asserts that every reader reports the documented absent-key result for `key`.
///
/// Three situations must be indistinguishable from each other: a key never written, a
/// key passed to `removeObject`, and a key cleared by writing `nil` through one of the
/// optional setters. Collecting the expectations here is what makes that sameness a
/// single statement rather than three lists that could drift apart.
///
/// `sourceLocation` is threaded through so a failure points at the calling case rather
/// than at this function.
@MainActor
func expectAbsent(
    _ store: any UserDefaultsStoreProtocol,
    key: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(store.bool(key) == false, sourceLocation: sourceLocation)
    #expect(store.int(key) == 0, sourceLocation: sourceLocation)
    #expect(store.double(key) == 0, sourceLocation: sourceLocation)
    #expect(store.string(key) == nil, sourceLocation: sourceLocation)
    #expect(store.stringArray(key) == nil, sourceLocation: sourceLocation)
    #expect(store.date(key) == nil, sourceLocation: sourceLocation)
    #expect(store.object(key) == nil, sourceLocation: sourceLocation)
}
