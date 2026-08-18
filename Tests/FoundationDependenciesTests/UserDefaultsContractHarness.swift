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

    /// `UserDefaultsLiveStore`, backed by a scratch suite created for the case and
    /// emptied again afterwards.
    case live

    /// `UserDefaultsTestStore`, backed by its own in-memory dictionary.
    case testDouble

    var testDescription: String {
        rawValue
    }
}

/// Runs `body` against a store of the given kind, created fresh for this case.
///
/// The live kind gets a scratch suite of its own. The name carries a UUID so cases
/// running in parallel can never land in the same suite, and the suite's contents are
/// removed afterwards whether the body passed, failed, or threw.
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
        let suiteName = scratchSuiteName()
        let store = try #require(
            UserDefaultsLiveStore(suiteName: suiteName),
            "Foundation refused the scratch suite name \(suiteName)"
        )
        defer {
            removeScratchSuite(named: suiteName)
        }
        try body(store)
    }
}

/// A suite name no other case will use.
///
/// The prefix is there so that a suite left behind by an interrupted run is traceable
/// back to this test target rather than looking like an app's own preferences.
func scratchSuiteName() -> String {
    "foundation-dependencies.contract.\(UUID().uuidString)"
}

/// Empties a scratch suite and deletes the file behind it.
///
/// `removePersistentDomain(forName:)` clears the contents but leaves an empty property
/// list on disk, so the two steps together are what stop a run from leaving residue
/// behind. Every case gets its own suite name, so without the second step a single run
/// of this target would drop well over a hundred empty files into the preferences
/// folder, and every later run would add as many again.
///
/// The path holds for a non-sandboxed process on macOS, which is what `swift test`
/// runs. Anywhere else the file is simply not found and the deletion does nothing,
/// which leaves the emptied suite exactly as `removePersistentDomain` left it rather
/// than failing the case.
func removeScratchSuite(named suiteName: String) {
    UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)

    let file = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Preferences")
        .appendingPathComponent("\(suiteName).plist")
    try? FileManager.default.removeItem(at: file)
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
